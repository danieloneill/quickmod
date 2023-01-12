#ifndef NXMHANDLER_H
#define NXMHANDLER_H

#include <QObject>
#include <QQmlApplicationEngine>

class NXMHandler : public QObject
{
    Q_OBJECT

public slots:
    Q_SCRIPTABLE QString download(const QString &arg);

signals:
    void downloadRequested(const QString &path);
};

#endif // NXMHANDLER_H
