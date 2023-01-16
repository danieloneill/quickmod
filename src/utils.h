#ifndef UTILS_H
#define UTILS_H

#include <QObject>

class Utils : public QObject
{
    Q_OBJECT

public:
    explicit Utils(QObject *parent = nullptr);

    Q_INVOKABLE QString uuid();
    Q_INVOKABLE void configSet(const QString &path, const QString &section, const QString &key, const QString &value);
    Q_INVOKABLE QString configGet(const QString &path, const QString &section, const QString &key);

    Q_INVOKABLE QString autoDecode(const QByteArray &encoded);

    Q_INVOKABLE QString urlFilename(const QString &url);
    Q_INVOKABLE QList< QPair<QString, QString> > urlQueryItems(const QString &url);

    Q_INVOKABLE QStringList envVars();
    Q_INVOKABLE QString getEnv(const QString &name);

signals:

};

#endif // UTILS_H
