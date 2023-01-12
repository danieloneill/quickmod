#include "file.h"

#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFileInfo>

#include <archive.h>
#include <archive_entry.h>

#define BUFFSIZE 32768 * 64

File::File(QObject *parent)
    : QObject{parent}
{

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
    QFile f(resolveCase(path));
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
    return QFile::copy(resolveCase(source), dest);
}

bool File::symlink(const QString &source, const QString &dest)
{
    return QFile::link(resolveCase(source), dest);
}

bool File::rm(const QString &path)
{
    return QFile::remove(resolveCase(path));
}

bool File::mkdir(const QString &path, bool createParents)
{
    QStringList parts = path.split('/');
    QString newDir = parts.takeLast();
    QString containerDir = parts.join('/');
    QDir dir(containerDir);
    if( createParents )
        return dir.mkpath(path);
    return dir.mkdir(newDir);
}

void File::mkfilepath(const char *path) {
    char tmp[256];
    char *p = NULL;
    size_t len;

    snprintf(tmp, sizeof(tmp), "%s", path);
    len = strlen(tmp);

    char *fsplit = rindex(tmp, '/');
    if( !fsplit )
            return;
    *fsplit = '\0';

    if (tmp[len - 1] == '/')
        tmp[len - 1] = '\0';

    for (p = tmp + 1; *p; p++)
    {
        if( *p == '/' )
        {
            *p = '\0';
            mkdir(tmp, S_IRWXU);
            *p = '/';
        }
    }
    mkdir(tmp, S_IRWXU);
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

    while( ARCHIVE_OK == archive_read_next_header(a, &entry) )
    {
        QString entrypath(archive_entry_pathname(entry));

#ifdef Q_OS_WINDOWS
        QString diskpath = QString(entrypath);
#else
        QString diskpath = entrypath.toLower();
#endif

        if( diskpath == filePath )
        {
            //qDebug() << QString("Extracting %1 -> %2...").arg(entrypath).arg(diskpath);
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
        nent["path"] = entrypath.toLower();
        result.append( nent );

        archive_read_data_skip(a);
    }
    r = archive_read_free(a);
    return result;
}

bool File::extractAll(const QString &archivePath, const QString &destDir)
{
    QByteArray result;
    struct archive *a;
    struct archive_entry *entry;
    int r;
    ssize_t size;

    a = archive_read_new();
    archive_read_support_filter_all(a);
    archive_read_support_format_all(a);
    r = archive_read_open_filename(a, archivePath.toStdString().c_str(), BUFFSIZE); // Note 1
    if (r != ARCHIVE_OK)
        return false;

    while( ARCHIVE_OK == archive_read_next_header(a, &entry) )
    {
        const struct stat *st = archive_entry_stat(entry);
        if( S_ISDIR(st->st_mode) )
            continue;

        QString entrypath(archive_entry_pathname(entry));
        QString diskpath = entrypath.toLower();
        QString fullpath = QString("%1/%2").arg(destDir).arg(diskpath);

        //qDebug() << QString("Extracting %1 \t-> %2...").arg(entrypath).arg(fullpath);

        mkfilepath(fullpath.toStdString().c_str());

        QFile f(diskpath);
        if( !f.open(QIODevice::WriteOnly) )
        {
            qDebug() << QString("Failed to open '%1': %2").arg(fullpath).arg(f.errorString());
            return false;
        }
        for (;;) {
            char buff[BUFFSIZE];

            size = archive_read_data(a, buff, BUFFSIZE);
            if (size < 0)
                break;

            if (size == 0)
                break;

            f.write(buff, size);
        }
        f.close();

        archive_read_data_skip(a);
    }
    r = archive_read_free(a);

    if( ARCHIVE_OK != r )
        return false;

    return true;
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

        mkfilepath(destFile.toStdString().c_str());

        QFile f(destFile);
        if( !f.open(QIODevice::WriteOnly | QIODevice::Truncate) )
        {
            qDebug() << QString("Failed to open '%1': %2").arg(destFile).arg(f.errorString());
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

/*
QString File::resolveCase(const QString &path)
{
    QDir d(path);
    QString abspath = d.absolutePath();

    QStringList parts = abspath.split('/');

    QString root =
}
*/
QString File::resolveCase(const QString &path)
{
    return path;
}
