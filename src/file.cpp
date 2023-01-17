#include "file.h"

#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFileInfo>

#include <archive.h>
#include <archive_entry.h>

#define BUFFSIZE 32768 * 64

static ssize_t arc_cb_read(struct archive *archive, void *userdata, const void **buf)
{
    Q_UNUSED(archive)

    ArchiveWorker *w = static_cast<ArchiveWorker *>(userdata);
    if( !w->m_fd )
        return -30;

    if( w->m_stopRequested )
        return 0;

    w->m_block = w->m_fd->read(BUFFSIZE);
    *buf = w->m_block.constData();
    //qDebug() << ":: arc_cb_read result:" << w->m_block.size();
    return w->m_block.size();
}

static int64_t arc_cb_skip(struct archive *archive, void *userdata, int64_t bytes)
{
    Q_UNUSED(archive)

    //qDebug() << ":: arc_cb_skip" << bytes;

    ArchiveWorker *w = static_cast<ArchiveWorker *>(userdata);
    if( !w->m_fd )
        return -1;

    if( w->m_stopRequested )
        return 0;

    qint64 pos = w->m_fd->pos();
    qint64 len = w->m_fd->size();
    if( pos + bytes > len )
        bytes = len - pos;

    qint64 npos = pos + bytes;
    if( !w->m_fd->seek(npos) )
        return 0;

    return bytes;
}

static int64_t arc_cb_seek(struct archive *archive, void *userdata, int64_t bytes, int whence)
{
    Q_UNUSED(archive)

    //qDebug() << ":: arc_cb_seek" << bytes << whence;

    ArchiveWorker *w = static_cast<ArchiveWorker *>(userdata);
    if( !w->m_fd )
        return -1;

    if( w->m_stopRequested )
        return 0;

    if( SEEK_SET == whence )
    {
        w->m_fd->seek(bytes);
    }
    else if( SEEK_CUR == whence )
    {
        qint64 pos = w->m_fd->pos();
        qint64 npos = pos + bytes;
        w->m_fd->seek(npos);
    }
    else if( SEEK_END == whence )
    {
        qint64 len = w->m_fd->size();
        qint64 npos = len - bytes;
        w->m_fd->seek(npos);
    }

    return w->m_fd->pos();
}

static int arc_cb_close(struct archive *archive, void *userdata)
{
    Q_UNUSED(archive)

    ArchiveWorker *w = static_cast<ArchiveWorker *>(userdata);
    if( !w->m_fd )
        return -1;

    w->m_fd->close();
    w->m_fd->deleteLater();
    w->m_fd = NULL;
    return ARCHIVE_OK;
}

ArchiveWorker::ArchiveWorker(ArchiveController *parent, File *file, const QString &archivePath)
    : QThread(parent),
      m_controller{parent},
      m_file{file},
      m_archivePath{archivePath},
      m_stopRequested{false}
{
    m_fd = new QFile(m_archivePath);
    if( !m_fd->open(QIODevice::ReadOnly) )
    {
        qWarning() << QObject::tr("Failed to open file \"%1\": %2").arg(m_archivePath).arg(m_fd->errorString());
        m_fd->deleteLater();
        m_fd = nullptr;
    }

    m_archive = archive_read_new();
    archive_read_support_filter_all(m_archive);
    archive_read_support_format_all(m_archive);
    archive_read_set_callback_data(m_archive, this);
    archive_read_set_read_callback(m_archive, arc_cb_read);
    archive_read_set_skip_callback(m_archive, arc_cb_skip);
    archive_read_set_seek_callback(m_archive, arc_cb_seek);
    archive_read_set_close_callback(m_archive, arc_cb_close);
    archive_read_open1(m_archive);
}

ArchiveWorker::~ArchiveWorker()
{
    m_stopRequested = true;

    if( m_fd )
        m_fd->deleteLater();

    archive_read_free(m_archive);
}

void ArchiveWorker::stop()
{
    m_stopRequested = true;
}

ArchiveListWorker::ArchiveListWorker(ArchiveController *parent, File *file, const QString &archivePath)
    : ArchiveWorker(parent, file, archivePath)
{
}

ArchiveListWorker::~ArchiveListWorker()
{
}

void ArchiveListWorker::run()
{
    struct archive_entry *entry = NULL;
    QVariantList results;

    if( !m_fd )
    {
        emit done(false, results);
        return;
    }

    while( !m_stopRequested && archive_read_next_header(m_archive, &entry) == ARCHIVE_OK )
    {
        QVariantMap ent;
        ent["pathname"] = archive_entry_pathname(entry);
        ent["size"] = QVariant::fromValue<qint64>(archive_entry_size(entry));

        mode_t mode = archive_entry_mode(entry);
        ent["type"] = "file";
        if( S_ISDIR(mode) )
            ent["type"] = "dir";

        results.append(ent);

        archive_read_data_skip(m_archive);
    }

    emit done(true, results);
}

ArchiveExtractToMemoryWorker::ArchiveExtractToMemoryWorker(ArchiveController *parent, File *file, const QString &archivePath, const QStringList &targets)
    : ArchiveWorker(parent, file, archivePath),
      m_targets{targets}
{
}

ArchiveExtractToMemoryWorker::~ArchiveExtractToMemoryWorker()
{
}

void ArchiveExtractToMemoryWorker::run()
{
    struct archive_entry *entry = NULL;
    ssize_t size;
    QVariantMap results;
    char buff[BUFFSIZE];

    if( !m_fd )
    {
        emit done(false, results);
        return;
    }

    QStringList lowKeys;
    for( QString target : m_targets )
        lowKeys << target.toLower();

    int position = 0;
    while( !m_stopRequested && archive_read_next_header(m_archive, &entry) == ARCHIVE_OK )
    {
        mode_t mode = archive_entry_mode(entry);
        QString path = QString::fromUtf8( archive_entry_pathname(entry) );
        QString lowPath = path.toLower();

        int kidx = lowKeys.indexOf(lowPath);
        if( -1 == kidx || S_ISDIR(mode) )
        {
            archive_read_data_skip(m_archive);
            continue;
        }

        QString thisfile = m_targets[kidx];

        QByteArray contents;
        for (;;) {
            size = archive_read_data(m_archive, buff, BUFFSIZE);
            if (size < 0)
            {
                if( m_stopRequested )
                {
                    emit done(false, results);
                    return;
                }

                results[thisfile] = false;
                //qDebug() << ":: error" << archive_error_string(m_archive);
                break;
            }

            if (size == 0)
                break;

            contents.append(buff, size);
        }
        position++;

        emit progress(position, lowKeys.length(), thisfile, QString());

        results[thisfile] = contents;
    }

    emit done(true, results);
}

ArchiveExtractToFileWorker::ArchiveExtractToFileWorker(ArchiveController *parent, File *file, const QString &archivePath, const QVariantMap &matrix)
    : ArchiveWorker(parent, file, archivePath),
      m_matrix{matrix}
{
}

ArchiveExtractToFileWorker::~ArchiveExtractToFileWorker()
{
}

void ArchiveExtractToFileWorker::run()
{
    struct archive_entry *entry = NULL;
    ssize_t size;
    QVariantMap results;
    char buff[BUFFSIZE];

    if( !m_fd )
    {
        emit done(false, results);
        return;
    }

    QStringList keys, lowKeys;
    for( QString target : m_matrix.keys() )
    {
        keys << target;
        lowKeys << target.toLower();
    }

    int position = 1;
    while( !m_stopRequested && archive_read_next_header(m_archive, &entry) == ARCHIVE_OK )
    {
        mode_t mode = archive_entry_mode(entry);
        QString path = QString::fromUtf8( archive_entry_pathname(entry) );
        QString lowPath = path.toLower();

        int kidx = lowKeys.indexOf(lowPath);
        if( -1 == kidx || S_ISDIR(mode) )
        {
            archive_read_data_skip(m_archive);
            continue;
        }

        QString thisfile = keys[kidx];
        QString dest = m_matrix[ thisfile ].toString();

        QString resolvedDest = m_file->resolveCase(dest);
        QFile f(resolvedDest);
        if( !m_file->mkfilepath(resolvedDest) || !f.open(QIODevice::WriteOnly | QIODevice::Truncate) )
        {
            emit progress(position++, lowKeys.length(), thisfile, dest);
            results[thisfile] = false;
            continue;
        }

        for (;;) {
            size = archive_read_data(m_archive, buff, BUFFSIZE);
            if (size < 0)
            {
                if( m_stopRequested )
                {
                    emit done(false, results);
                    return;
                }

                qDebug() << ":: error" << archive_error_string(m_archive);
                break;
            }

            if (size == 0)
                break;

            f.write(buff, size);
        }

        f.flush();
        f.close();

        emit progress(position++, lowKeys.length(), thisfile, dest);
        results[thisfile] = true;
    }

    emit done(true, results);
}

ArchiveController::ArchiveController(const QString &archivePath, File *file)
    : QObject(file),
      m_file{file},
      m_archivePath{archivePath}
{
}

ArchiveController::~ArchiveController()
{
    qDebug() << "ArchiveController::~ArchiveController()";
}

ArchiveListWorker *ArchiveController::list(QJSValue finished)
{
    if( !m_fileListing.isEmpty() )
    {
        if( finished.isCallable() )
        {
            QJSValueList args;
            args << m_file->m_engine->toScriptValue(true);
            args << m_file->m_engine->toScriptValue(m_fileListing);
            finished.call(args);
        }

        return NULL;
    }

    ArchiveListWorker *w = new ArchiveListWorker(this, m_file, m_archivePath);
    connect(w, &ArchiveListWorker::done, this, &ArchiveController::listFinished);
    connect(w, &ArchiveWorker::finished, w, &QObject::deleteLater);
    m_callmap[w] = QPair(QJSValue(), finished);

    w->start();
    return w;
}

ArchiveExtractToMemoryWorker *ArchiveController::get(const QStringList &targets, QJSValue finished, QJSValue progress)
{
    ArchiveExtractToMemoryWorker *w = new ArchiveExtractToMemoryWorker(this, m_file, m_archivePath, targets);
    connect( w, &ArchiveExtractToMemoryWorker::done, this, &ArchiveController::extractToMemoryFinished );
    connect( w, &ArchiveExtractToMemoryWorker::progress, this, &ArchiveController::workerProgress );
    connect(w, &ArchiveWorker::finished, w, &QObject::deleteLater);
    m_callmap[w] = QPair(progress, finished);

    w->start();
    return w;
}

ArchiveExtractToFileWorker *ArchiveController::extract(const QVariantMap &matrix, QJSValue finished, QJSValue progress)
{
    ArchiveExtractToFileWorker *w = new ArchiveExtractToFileWorker(this, m_file, m_archivePath, matrix);
    connect( w, &ArchiveExtractToFileWorker::done, this, &ArchiveController::extractToFileFinished );
    connect( w, &ArchiveExtractToFileWorker::progress, this, &ArchiveController::workerProgress );
    connect(w, &ArchiveWorker::finished, w, &QObject::deleteLater);
    m_callmap[w] = QPair(progress, finished);

    w->start();
    return w;
}

void ArchiveController::listFinished(bool result, const QVariantList &entries)
{
    ArchiveWorker *w = qobject_cast<ArchiveWorker *>(sender());
    m_fileListing = entries;
    QJSValue *cb_f = &m_callmap[w].second;
    if( cb_f->isCallable() )
    {
        QJSValueList args;
        args << m_file->m_engine->toScriptValue(result);
        args << m_file->m_engine->toScriptValue(entries);
        cb_f->call(args);
    }
    w->deleteLater();
    m_callmap.remove(w);
}

void ArchiveController::extractToMemoryFinished(bool result, const QVariantMap &contents)
{
    ArchiveWorker *w = qobject_cast<ArchiveWorker *>(sender());
    QJSValue *cb_f = &m_callmap[w].second;
    if( cb_f->isCallable() )
    {
        QJSValueList args;
        args << m_file->m_engine->toScriptValue(result);
        args << m_file->m_engine->toScriptValue<QVariantMap>(contents);
        cb_f->call(args);
    }
    w->deleteLater();
    m_callmap.remove(w);
}

void ArchiveController::extractToFileFinished(bool result, const QVariantMap &contents)
{
    ArchiveWorker *w = qobject_cast<ArchiveWorker *>(sender());
    QJSValue *cb_f = &m_callmap[w].second;
    if( cb_f->isCallable() )
    {
        QJSValueList args;
        args << m_file->m_engine->toScriptValue(result);
        args << m_file->m_engine->toScriptValue<QVariantMap>(contents);
        cb_f->call(args);
    }
    w->deleteLater();
    m_callmap.remove(w);
}

void ArchiveController::workerProgress(qreal processed, qreal total, const QString &latestSource, const QString &latestDest)
{
    ArchiveWorker *w = qobject_cast<ArchiveWorker *>(sender());
    QJSValue *cb_p = &m_callmap[w].first;
    if( cb_p->isCallable() )
    {
        QJSValueList args;
        args << m_file->m_engine->toScriptValue(processed);
        args << m_file->m_engine->toScriptValue(total);
        args << m_file->m_engine->toScriptValue(latestSource);
        args << m_file->m_engine->toScriptValue(latestDest);
        cb_p->call(args);
    }
}

File::File(QQmlApplicationEngine *engine)
    : m_engine{engine},
      m_simulate{false}
{

}

bool File::simulate() { return m_simulate; }
void File::setSimulate(bool onoff)
{
    if( onoff == m_simulate )
        return;

    m_simulate = onoff;
    emit simulateChanged(onoff);
}

QVariant File::stat(const QString &path)
{
    QString p = resolveCase(path);
    QFileInfo info(p);
    QVariantMap res;

    res["absoluteFilePath"] = info.absoluteFilePath();
    res["absolutePath"] = info.absolutePath();
    res["baseName"] = info.baseName();
    res["exists"] = info.exists();
    res["fileName"] = info.fileName();
    res["filePath"] = info.filePath();
    res["group"] = info.group();
    res["groupId"] = info.groupId();
    res["isAbsolute"] = info.isAbsolute();
    res["isDir"] = info.isDir();
    res["isExecutable"] = info.isExecutable();
    res["isFile"] = info.isFile();
    res["isHidden"] = info.isHidden();
    res["isReadable"] = info.isReadable();
    res["isSymlink"] = info.isSymLink();
    res["lastModified"] = info.lastModified();
    res["owner"] = info.owner();
    res["ownerId"] = info.ownerId();
    res["path"] = info.path();
/*
    QFile::Permissions perms = info.permissions();
    QVariantMap permMap;
    if( perms & QFileDevice::ReadOwner )
        res["ReadOwner"] = true;
    if( perms & QFileDevice::ReadOwner )
        res["ReadOwner"] = true;
    if( perms & QFileDevice::ReadOwner )
        res["ReadOwner"] = true;

    res["permissions"] = permMap;
*/
    return res;
}

bool File::write(const QString &path, const QByteArray &data)
{
    QString rpath = resolveCase(path);
    QFile f(rpath);
    if( m_simulate )
    {
        qDebug() << tr("SIMULATE: Write %1 bytes to \"%2\"").arg(data.length()).arg(rpath);
        return true;
    }

    if( !f.open(QIODevice::WriteOnly) )
        return false;

    if( data.length() != f.write(data) )
    {
        f.close();
        return false;
    }

    f.close();
    return true;
}

QByteArray File::read(const QString &path)
{
    QByteArray result;
    QString rpath = path;
    if( !rpath.startsWith(':') )
        rpath = resolveCase(path);

    QFile f(rpath);
    if( !f.open(QIODevice::ReadOnly) )
        return result;

    result = f.readAll();
    f.close();

    return result;
}

bool File::copy(const QString &source, const QString &dest)
{
    QString rsource = resolveCase(source);
    QString rdest = resolveCase(dest);

    if( m_simulate )
    {
        qDebug() << tr("SIMULATE: Copy \"%1\" to \"%2\"").arg(rsource).arg(rdest);
        return true;
    }
    return QFile::copy(rsource, dest);
}

bool File::rm(const QString &path)
{
    QString rpath = resolveCase(path);
    if( m_simulate )
    {
        qDebug() << tr("SIMULATE: Remove \"%1\"").arg(rpath);
        return true;
    }

    return QFile::remove(rpath);
}

bool File::rmrecursive(const QString &path)
{
    QString rpath = resolveCase(path);
    QDir d(rpath);
    if( m_simulate )
    {
        qDebug() << tr("SIMULATE: Remove (recursive): \"%1\"").arg(rpath);
        return d.exists();
    }
    return d.removeRecursively();
}

bool File::mkdir(const QString &path, bool createParents)
{
    QString rpath = resolveCase(path);
    QStringList parts = rpath.split('/');
    QString newDir = parts.takeLast();
    QString containerDir = parts.join('/');
    QDir dir(containerDir);
    if( createParents )
    {
        if( m_simulate )
        {
            qDebug() << tr("SIMULATE: Mkpath \"%1\"").arg(rpath);
            return true;
        }
        return QDir::root().mkpath(rpath);
    }

    if( m_simulate )
    {
        qDebug() << tr("SIMULATE: Mkdir \"%1\" in \"%2\"").arg(newDir).arg(containerDir);
        return true;
    }
    return dir.mkdir(newDir);
}

// Given: "/home/leetguy/code/thisthing.png"
// Create: "/home/leetguy/code"
bool File::mkfilepath(const QString &path)
{
    QString rpath = resolveCase(path);
    QStringList parts = rpath.split('/');
    QString newDir = parts.takeLast();
    QString containerDir = parts.join('/');
    QDir dir = QDir::root();

    if( m_simulate )
    {
        qDebug() << tr("SIMULATE: Mkpath \"%1\"").arg(containerDir);
        return true;
    }

    return dir.mkpath(containerDir);
}

QVariant File::dirContents(const QString &path)
{
    QVariantList results;
    QDir dir(path);
    if( !dir.exists() )
        return results;

    auto entries = dir.entryInfoList(QDir::NoFilter, QDir::DirsFirst | QDir::Name);
    for( QFileInfo fi : entries )
    {
        QVariantMap nfi;
        nfi["type"] = fi.isDir() ? "dir" : "file";
        nfi["filePath"] = fi.filePath();
        nfi["fileName"] = fi.fileName();
        nfi["exists"] = fi.exists();
        nfi["path"] = fi.path();
        results << nfi;
    }
    return results;
}
/*
QByteArray File::extract(const QString &archivePath, const QString &filePath)
{
    QByteArray result;
    struct archive *a;
    struct archive_entry *entry;
    int r;
    ssize_t size;
    char buff[BUFFSIZE];

    a = archive_read_new();
    archive_read_support_filter_all(a);
    archive_read_support_format_all(a);
    r = archive_read_open_filename(a, archivePath.toStdString().c_str(), BUFFSIZE); // Note 1
    if (r != ARCHIVE_OK)
        return result;

    QString fileLow = filePath.toLower();
    while( ARCHIVE_OK == archive_read_next_header(a, &entry) )
    {
        QString entrypath(archive_entry_pathname(entry));

#ifdef Q_OS_WINDOWS
        QString diskpath = QString(entrypath);
#else
        QString diskpath = entrypath.toLower();
#endif

        if( diskpath == fileLow )
        {
            qDebug() << QString("Extracting %1 -> %2...").arg(entrypath).arg(diskpath);
            for (;;) {
                size = archive_read_data(a, buff, BUFFSIZE);
                if (size < 0)
                    break;

                if (size == 0)
                    break;

                result.append(buff, size);
            }
            break;
        }

        archive_read_data_skip(a);
    }
    r = archive_read_free(a);

    if (r != ARCHIVE_OK)
        qDebug() << "Encountered an error reading data!";

    return result;
}

QVariant File::archiveList(const QString &archivePath)
{
    QVariantList result;
    struct archive *a;
    struct archive_entry *entry;
    int r;

    a = archive_read_new();
    archive_read_support_filter_all(a);
    archive_read_support_format_all(a);
    r = archive_read_open_filename(a, archivePath.toStdString().c_str(), BUFFSIZE); // Note 1
    if (r != ARCHIVE_OK)
        return QVariant(false);

    while( ARCHIVE_OK == archive_read_next_header(a, &entry) )
    {
        const struct stat *st = archive_entry_stat(entry);
        QVariantMap nent;
        nent["type"] = "file";
        if( S_ISDIR(st->st_mode) )
            nent["type"] = "dir";

        QString entrypath(archive_entry_pathname(entry));
        nent["path"] = entrypath;
        result.append( nent );

        archive_read_data_skip(a);
    }
    r = archive_read_free(a);
    return result;
}

bool File::extractSourceDest(const QString &archivePath, const QString &srcFile, const QString &destFile)
{
    QByteArray result;
    struct archive *a;
    struct archive_entry *entry;
    int r;
    ssize_t size;
    char buff[BUFFSIZE];
    bool retval = false;

    a = archive_read_new();
    archive_read_support_filter_all(a);
    archive_read_support_format_all(a);
    r = archive_read_open_filename(a, archivePath.toStdString().c_str(), BUFFSIZE); // Note 1
    if (r != ARCHIVE_OK)
        return false;

    QString sourceLow = srcFile.toLower();
    while( ARCHIVE_OK == archive_read_next_header(a, &entry) )
    {
        const struct stat *st = archive_entry_stat(entry);
        if( S_ISDIR(st->st_mode) )
            continue;

        QString entrypath(archive_entry_pathname(entry));

#ifdef Q_OS_WINDOWS
        QString diskpath = QString(entrypath);
#else
        QString diskpath = entrypath.toLower();
#endif

        if( diskpath == sourceLow )
        {
            archive_read_data_skip(a);
            continue;
        }

        QString resolved = resolveCase(destFile);
        mkfilepath(resolved);

        QFile f(resolved);
        if( !f.open(QIODevice::WriteOnly | QIODevice::Truncate) )
        {
            qDebug() << QString("Failed to open '%1': %2").arg(resolved).arg(f.errorString());
            return false;
        }

        for (;;) {
            size = archive_read_data(a, buff, BUFFSIZE);
            if (size < 0)
                break;

            if (size == 0)
                break;

            f.write(buff, size);
        }
        retval = 0 == size;
        f.close();
        break;
    }

    r = archive_read_free(a);

    if( ARCHIVE_OK != r )
        return false;

    return retval;
}

bool File::extractBatch(const QString &archivePath, const QVariantMap &fileMap)
{
    QByteArray result;
    struct archive *a;
    struct archive_entry *entry;
    int r;
    ssize_t size;
    char buff[BUFFSIZE];
    bool retval = false;

    a = archive_read_new();
    archive_read_support_filter_all(a);
    archive_read_support_format_all(a);
    r = archive_read_open_filename(a, archivePath.toStdString().c_str(), BUFFSIZE); // Note 1
    if (r != ARCHIVE_OK)
        return false;

    QStringList keys = fileMap.keys();
    QStringList lowKeys;
    for( QString k : keys )
        lowKeys << k.toLower();

    int processed = 0;
    while( ARCHIVE_OK == archive_read_next_header(a, &entry) )
    {
        const struct stat *st = archive_entry_stat(entry);
        if( S_ISDIR(st->st_mode) )
            continue;

        QString entrypath(archive_entry_pathname(entry));
        QString diskpath = entrypath.toLower();
        int entpos = lowKeys.indexOf(diskpath);
        if( -1 == entpos )
        {
            archive_read_data_skip(a);
            continue;
        }

        QString destFile = fileMap[ keys[entpos] ].toString();
        QString resolved = resolveCase(destFile);
        mkfilepath(resolved);

        qDebug() << tr("Extracting '%1' to '%2'...").arg(diskpath).arg(resolved);
        if( !m_simulate )
        {
            QFile f(resolved);
            if( !f.open(QIODevice::WriteOnly | QIODevice::Truncate) )
            {
                qDebug() << QString("Failed to open '%1': %2").arg(resolved).arg(f.errorString());
                return false;
            }

            for (;;) {
                size = archive_read_data(a, buff, BUFFSIZE);
                if (size < 0)
                    break;

                if (size == 0)
                    break;

                f.write(buff, size);
            }
            retval = 0 == size;
            f.close();
        }

        processed++;
        if( processed == keys.length() )
            break;
    }

    r = archive_read_free(a);

    if( ARCHIVE_OK != r )
        return false;

    return retval;
}
*/
ArchiveController *File::archive(const QString &archivePath)
{
    ArchiveController *ac = new ArchiveController(archivePath, this);
    return ac;
}

QString File::resolveCaseDir(const QDir &root, const QString &part)
{
#define CHECK_COLLISIONS
#ifdef CHECK_COLLISIONS
    QStringList matches;
#endif
    QStringList ents = root.entryList();
    for( QString ent : ents )
    {
        if( ent.toLower() == part.toLower() )
#ifdef CHECK_COLLISIONS
            matches << ent;
#else
            return ent;
#endif
    }

#ifdef CHECK_COLLISIONS
    if( matches.length() > 1 )
    {
        qCritical() << tr("Multiple matching targets of '%1' found in '%2':").arg(part).arg(root.absolutePath());
        for( QString m : matches )
            qCritical() << " -" << m;
    } else if( matches.isEmpty() )
        return part;
    return matches[0];
#else
    return part;
#endif
}

QString File::resolveCase(const QString &path)
{
    QString cleaned = QDir::cleanPath(path);
    QStringList parts = cleaned.split('/', Qt::SkipEmptyParts);

    QString resultPath;
    QStringList results;

    QDir d = QDir::root();
    for( QString part : parts )
    {
        results << resolveCaseDir(d, part);
        resultPath = QString("/").append( results.join('/') );
        d = QDir( resultPath );
    }
    return resultPath;
}

/*
QString File::resolveCase(const QString &path)
{
    return path;
}
*/
