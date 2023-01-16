#include "file.h"

#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFileInfo>

#include <archive.h>
#include <archive_entry.h>

#define BUFFSIZE 32768 * 64

File::File(QObject *parent)
    : QObject{parent},
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

    QFile f(resolveCase(path));
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
