#ifndef FILE_H
#define FILE_H

#include <QDir>
#include <QObject>
#include <QVariant>

class File : public QObject
{
    Q_OBJECT

    Q_PROPERTY( bool simulate WRITE setSimulate READ simulate NOTIFY simulateChanged )

public:
    explicit File(QObject *parent = nullptr);

    Q_INVOKABLE QVariant stat(const QString &path);
    Q_INVOKABLE bool write(const QString &path, const QByteArray &data);
    Q_INVOKABLE QByteArray read(const QString &path);
    Q_INVOKABLE bool copy(const QString &source, const QString &dest);
    Q_INVOKABLE bool rm(const QString &path);
    Q_INVOKABLE bool rmrecursive(const QString &path);
    Q_INVOKABLE bool mkdir(const QString &path, bool createParents=false);
    Q_INVOKABLE bool mkfilepath(const QString &path);
    Q_INVOKABLE QVariant dirContents(const QString &path);

    Q_INVOKABLE QVariant archiveList(const QString &archivePath);
    Q_INVOKABLE QByteArray extract(const QString &archivePath, const QString &filePath);
    Q_INVOKABLE bool extractSourceDest(const QString &archivePath, const QString &srcFile, const QString &destFile);
    Q_INVOKABLE bool extractBatch(const QString &archivePath, const QVariantMap &fileMap);

    Q_INVOKABLE QString resolveCase(const QString &path);

    Q_INVOKABLE bool simulate();
    Q_INVOKABLE void setSimulate(bool onoff);

private:
    QString resolveCaseDir(const QDir &root, const QString &part);

    bool m_simulate;

signals:
    void simulateChanged(bool simulate);

};

#endif // FILE_H
