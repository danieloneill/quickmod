#include "utils.h"

#include <QDebug>
#include <QProcessEnvironment>
#include <QSettings>
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
# include <QStringDecoder>
#else
# include <QTextCodec>
#endif
#include <QUrl>
#include <QUrlQuery>
#include <QUuid>

Utils::Utils(QObject *parent)
    : QObject{parent}
{

}

QString Utils::uuid()
{
    return QUuid::createUuid().toString();
}

void Utils::configSet(const QString &path, const QString &section, const QString &key, const QString &value)
{
    QSettings s(path, QSettings::IniFormat);
    if( !section.isEmpty() )
        s.beginGroup(section);
    s.setValue(key, value);
    if( !section.isEmpty() )
        s.endGroup();
    s.sync();
}

QString Utils::configGet(const QString &path, const QString &section, const QString &key)
{
    QVariant result;
    QSettings s(path, QSettings::IniFormat);
    if( !section.isEmpty() )
        s.beginGroup(section);
    result = s.value(key);
    if( !section.isEmpty() )
        s.endGroup();
    s.sync();
    return result.toString();
}

QString Utils::autoDecode(const QByteArray &encoded)
{
#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
    QTextCodec *codec = QTextCodec::codecForUtfText(encoded);
    return codec->toUnicode(encoded);
#else
    std::optional<QStringConverter::Encoding> enc = QStringConverter::encodingForData(encoded);
    if( !enc.has_value() )
    {
        qDebug() << "Can't discern the encoding of this content, sorry.";
        return QString::fromLocal8Bit(encoded);
    }

    //qDebug() << "Transcoding from" << QStringConverter::nameForEncoding(enc.value()) << "to QString (UTF16)";

    auto dec = QStringDecoder(enc.value());
    return dec(encoded);
#endif
}

QString Utils::urlFilename(const QString &url)
{
    QUrl u(url);
    return u.fileName();
}

QList< QPair<QString, QString> > Utils::urlQueryItems(const QString &url)
{
    QUrl u(url);
    QUrlQuery q(u);
    return q.queryItems();
}

QStringList Utils::envVars()
{
    return QProcessEnvironment::systemEnvironment().keys();
}

QString Utils::getEnv(const QString &name)
{
    return QProcessEnvironment::systemEnvironment().value(name);
}
