#ifndef FILE_H
#define FILE_H

#include <QObject>
#include <QVariant>

class File : public QObject
{
    Q_OBJECT

public:
    explicit File(QObject *parent = nullptr);

    Q_INVOKABLE QVariant stat(const QString &path);
    Q_INVOKABLE bool write(const QString &path, const QByteArray &data);
    Q_INVOKABLE QByteArray read(const QString &path);
    Q_INVOKABLE bool copy(const QString &source, const QString &dest);
    Q_INVOKABLE bool symlink(const QString &source, const QString &dest);
    Q_INVOKABLE bool rm(const QString &path);
    Q_INVOKABLE bool mkdir(const QString &path, bool createParents=false);

    Q_INVOKABLE QVariant archiveList(const QString &archivePath);
    Q_INVOKABLE QByteArray extract(const QString &archivePath, const QString &filePath);
    Q_INVOKABLE bool extractAll(const QString &archivePath, const QString &destDir);
    Q_INVOKABLE bool extractSourceDest(const QString &archivePath, const QString &srcFile, const QString &destFile);

    void mkfilepath(const char *path);

private:
    Q_INVOKABLE QString resolveCase(const QString &path);

signals:

};

#endif // FILE_H
