#ifndef HTTP_H
#define HTTP_H

#include <QJSValue>
#include <QNetworkAccessManager>
#include <QObject>
#include <QQmlApplicationEngine>

class HTTP : public QObject
{
    Q_OBJECT

    QQmlApplicationEngine   *m_engine;
    QNetworkAccessManager   *m_qnam;

public:
    explicit HTTP(QQmlApplicationEngine *engine);

    Q_INVOKABLE bool get(const QString &url, QJSValue &callback, const QVariant &headers);
    Q_INVOKABLE bool getFile(const QString &url, const QString &destPath, QJSValue &callback, const QVariant &headers);
};

#endif // HTTP_H
