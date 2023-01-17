#ifndef HTTP_H
#define HTTP_H

#include <QJSValue>
#include <QNetworkAccessManager>
#include <QObject>
#include <QQmlApplicationEngine>

class HTTP;
class HTTPHandle : public QObject
{
    Q_OBJECT

    QNetworkReply   *m_reply;

public:
    HTTPHandle(HTTP *parent, QNetworkReply *reply);
    ~HTTPHandle();

    Q_INVOKABLE void stop();
};

class HTTP : public QObject
{
    Q_OBJECT

    QQmlApplicationEngine   *m_engine;
    QNetworkAccessManager   *m_qnam;

public:
    explicit HTTP(QQmlApplicationEngine *engine);

    Q_INVOKABLE HTTPHandle *get(const QString &url, QJSValue callback, const QVariant &headers=QVariant(), QJSValue progcb=QJSValue());
    Q_INVOKABLE HTTPHandle *getFile(const QString &url, const QString &destPath, QJSValue callback=QJSValue(), const QVariant &headers=QVariant(), QJSValue progcb=QJSValue());
};

#endif // HTTP_H
