#ifndef FOMODREADER_H
#define FOMODREADER_H

#include <QObject>
#include <QQuickItem>
#include <QXmlStreamReader>

class FOMODReader : public QObject
{
    Q_OBJECT

    QXmlStreamReader m_reader;

public:
    explicit FOMODReader(QObject *parent = nullptr);

    Q_INVOKABLE QVariant readXMLFile(const QString &xml);

private:
    QVariant xmlStreamToVariant(QXmlStreamReader &xml, const QString &prefix = QLatin1String("."), const int maxDepth = 1024);

signals:

};

#endif // FOMODREADER_H
