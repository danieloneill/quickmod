#ifndef FILE_H
#define FILE_H

#include <QDir>
#include <QJSValue>
#include <QObject>
#include <QQmlApplicationEngine>
#include <QThread>
#include <QVariant>

class ArchiveController;
class ArchiveWorker;
class File;

class ArchiveWorker : public QThread
{
    Q_OBJECT

    virtual void run() = 0;

public:
    ArchiveController *m_controller;
    File           *m_file;
    QString         m_archivePath;
    bool            m_stopRequested;

    QFile          *m_fd;
    struct archive *m_archive;
    QByteArray      m_block;

    ArchiveWorker(ArchiveController *parent, File *file, const QString &archivePath);
    ~ArchiveWorker();

public slots:
    void stop();
};

class ArchiveListWorker : public ArchiveWorker
{
    Q_OBJECT

    void run() override;

public:
    ArchiveListWorker(ArchiveController *parent, File *file, const QString &archivePath);
    ~ArchiveListWorker();

signals:
    void done(bool result, const QVariantList &results);
};

class ArchiveExtractToMemoryWorker : public ArchiveWorker
{
    Q_OBJECT

    QStringList     m_targets;

    void run() override;

public:
    ArchiveExtractToMemoryWorker(ArchiveController *parent, File *file, const QString &archivePath, const QStringList &targets);
    ~ArchiveExtractToMemoryWorker();

signals:
    void done(bool result, const QVariantMap &contents);
    void progress(qreal position, qreal total, const QString &latestFile, const QString &dest);
};

class ArchiveExtractToFileWorker : public ArchiveWorker
{
    Q_OBJECT

    QVariantMap     m_matrix;

    void run() override;

public:
    ArchiveExtractToFileWorker(ArchiveController *parent, File *file, const QString &archivePath, const QVariantMap &matrix);
    ~ArchiveExtractToFileWorker();

signals:
    void done(bool result, const QVariantMap &contents);
    void progress(qreal position, qreal total, const QString &latestFile, const QString &latestDest);
};

class ArchiveController : public QObject
{
    Q_OBJECT

    File        *m_file;
    QString     m_archivePath;
    QVariantList m_fileListing;

    QMap< ArchiveWorker *, QPair<QJSValue, QJSValue> > m_callmap;

public:
    ArchiveController(const QString &archivePath, File *file);
    ~ArchiveController();

    Q_INVOKABLE ArchiveListWorker *list(QJSValue finished);
    Q_INVOKABLE ArchiveExtractToMemoryWorker *get(const QStringList &targets, QJSValue finished, QJSValue progress=QJSValue());
    Q_INVOKABLE ArchiveExtractToFileWorker *extract(const QVariantMap &matrix, QJSValue finished, QJSValue progress=QJSValue());

private slots:
    void listFinished(bool result, const QVariantList &entries);
    void extractToMemoryFinished(bool result, const QVariantMap &contents);
    void extractToFileFinished(bool result, const QVariantMap &contents);
    void workerProgress(qreal processed, qreal total, const QString &latestSource, const QString &latestDest);
};

class File : public QObject
{
    Q_OBJECT

    Q_PROPERTY( bool simulate WRITE setSimulate READ simulate NOTIFY simulateChanged )

public:
    explicit File(QQmlApplicationEngine *engine);

    Q_INVOKABLE QVariant stat(const QString &path);
    Q_INVOKABLE bool write(const QString &path, const QByteArray &data);
    Q_INVOKABLE QByteArray read(const QString &path);
    Q_INVOKABLE bool copy(const QString &source, const QString &dest);
    Q_INVOKABLE bool rm(const QString &path);
    Q_INVOKABLE bool rmrecursive(const QString &path);
    Q_INVOKABLE bool mkdir(const QString &path, bool createParents=false);
    Q_INVOKABLE bool mkfilepath(const QString &path);
    Q_INVOKABLE QVariant dirContents(const QString &path);
/*
    Q_INVOKABLE QVariant archiveList(const QString &archivePath);
    Q_INVOKABLE QByteArray extract(const QString &archivePath, const QString &filePath);
    Q_INVOKABLE bool extractSourceDest(const QString &archivePath, const QString &srcFile, const QString &destFile);
    Q_INVOKABLE bool extractBatch(const QString &archivePath, const QVariantMap &fileMap);
*/
    Q_INVOKABLE ArchiveController *archive(const QString &archivePath);

    Q_INVOKABLE QString resolveCase(const QString &path);

    Q_INVOKABLE bool simulate();
    Q_INVOKABLE void setSimulate(bool onoff);

    QQmlApplicationEngine *m_engine;

private:
    QString resolveCaseDir(const QDir &root, const QString &part);

    bool m_simulate;

signals:
    void simulateChanged(bool simulate);

};

#endif // FILE_H
