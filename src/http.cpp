#include "http.h"

#include <QFile>
#include <QIODevice>
#include <QNetworkReply>

HTTP::HTTP(QQmlApplicationEngine *engine)
    : QObject{nullptr},
      m_engine(engine)
{
    m_qnam = new QNetworkAccessManager(this);
}

bool HTTP::get(const QString &url, QJSValue callback, const QVariant &headers, QJSValue progcb)
{
    QNetworkRequest request;
    request.setUrl(QUrl(url));
    request.setRawHeader("User-Agent", "Quickmod 1.0");

    if( !headers.isNull() )
    {
        if( !headers.canConvert<QVariantMap>() )
        {
            m_engine->throwError(tr("HTTP.get expects a single object for headers"));
            return false;
        }

        QVariantMap asmap = headers.toMap();
        for( QString k : asmap.keys() )
        {
            if( !asmap[k].canConvert<QString>() )
                continue;

            request.setRawHeader(k.toUtf8(), asmap[k].toString().toUtf8());
        }
    }

    QByteArray *result = new QByteArray();

    QNetworkReply *reply = m_qnam->get(request);
    if( progcb.isCallable() )
    {
        connect(reply, &QNetworkReply::downloadProgress, this, [this, progcb](qint64 recv, qint64 tot) mutable {
            QJSValueList args;
            QJSValue dataA = this->m_engine->toScriptValue(recv);
            QJSValue dataB = this->m_engine->toScriptValue(tot);
            args << dataA;
            args << dataB;
            progcb.call(args);
        });
    }
    connect(reply, &QIODevice::readyRead, this, [result, reply]() mutable {
        result->append(reply->read(32768));
    });
    connect(reply, &QNetworkReply::finished, this, [reply, result, this, callback]() mutable {
        if( callback.isCallable() )
        {
            QJSValueList args;
            QJSValue status = this->m_engine->toScriptValue<QString>("OK");
            QJSValue data = this->m_engine->toScriptValue(*result);

            args << status;
            args << data;
            callback.call(args);
        }
        reply->deleteLater();
    });
    connect(reply, &QNetworkReply::errorOccurred, this, [reply, this, callback]() mutable {
        if( callback.isCallable() )
        {
            QJSValueList args;
            QJSValue status = this->m_engine->toScriptValue<QString>("ERROR");
            QJSValue data = this->m_engine->toScriptValue<QString>(reply->errorString());
            args << status;
            args << data;
            callback.call(args);
        }
        reply->deleteLater();
    });

    return reply->error() == QNetworkReply::NoError;
}

bool HTTP::getFile(const QString &url, const QString &destPath, QJSValue callback, const QVariant &headers, QJSValue progcb)
{
    QNetworkRequest request;
    request.setUrl(QUrl(url));
    request.setRawHeader("User-Agent", "Quickmod 1.0");

    if( !headers.isNull() )
    {
        if( !headers.canConvert<QVariantMap>() )
        {
            m_engine->throwError(tr("HTTP.get expects a single object for headers"));
            return false;
        }

        QVariantMap asmap = headers.toMap();
        for( QString k : asmap.keys() )
        {
            if( !asmap[k].canConvert<QString>() )
                continue;

            request.setRawHeader(k.toUtf8(), asmap[k].toString().toUtf8());
        }
    }

    QFile *file = new QFile(destPath);
    file->open(QIODevice::WriteOnly | QIODevice::Truncate);

    QNetworkReply *reply = m_qnam->get(request);
    if( progcb.isCallable() )
    {
        connect(reply, &QNetworkReply::downloadProgress, this, [this, progcb](qint64 recv, qint64 tot) mutable {
            QJSValueList args;
            QJSValue dataA = this->m_engine->toScriptValue(recv);
            QJSValue dataB = this->m_engine->toScriptValue(tot);
            args << dataA;
            args << dataB;
            progcb.call(args);
        });
    }
    connect(reply, &QIODevice::readyRead, this, [file, reply]() mutable {
        file->write( reply->readAll() );
    });
    connect(reply, &QNetworkReply::finished, this, [reply, file, destPath, this, callback]() mutable {
        file->close();
        file->deleteLater();

        if( callback.isCallable() )
        {
            QJSValueList args;
            QJSValue status = this->m_engine->toScriptValue<QString>("OK");
            QJSValue data = this->m_engine->toScriptValue(destPath);

            args << status;
            args << data;
            callback.call(args);
        }
        reply->deleteLater();
    });
    connect(reply, &QNetworkReply::errorOccurred, this, [reply, file, destPath, this, callback]() mutable {
        file->flush();
        file->close();
        file->deleteLater();

        if( callback.isCallable() )
        {
            QJSValueList args;
            QJSValue status = this->m_engine->toScriptValue<QString>("ERROR");
            QJSValue data = this->m_engine->toScriptValue(destPath);

            args << status;
            args << data;
            callback.call(args);
        }

        reply->deleteLater();
    });

    return reply->error() == QNetworkReply::NoError;
}
