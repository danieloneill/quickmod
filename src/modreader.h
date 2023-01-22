#ifndef MODREADER_H
#define MODREADER_H

#include <QIODevice>
#include <QObject>
#include <QVariant>

class File;
class ModReader : public QObject
{
    Q_OBJECT

    File    *m_file;

public:
    explicit ModReader(File *file);

    Q_INVOKABLE QVariant readSkyrimMod(const QString &path);

private:
    bool readZString(QIODevice &src, QString *dest);

signals:

};

#endif // MODREADER_H
