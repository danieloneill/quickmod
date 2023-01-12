#include "fomodreader.h"

#include <QtGlobal>
#include <QFile>

FOMODReader::FOMODReader(QObject *parent)
    : QObject{parent}
{

}

QVariant FOMODReader::readXMLFile(const QString &xml)
{
    m_reader.clear();
    m_reader.addData(xml);

    QVariant result = xmlStreamToVariant(m_reader, "", 128);
    return result;
}

QVariant FOMODReader::xmlStreamToVariant(QXmlStreamReader &xml, const QString &prefix, const int maxDepth)
{
    if (maxDepth < 0) {
        qWarning() << QObject::tr("max depth exceeded");
        return QVariantMap();
    }

    if (xml.hasError()) {
        qWarning() << xml.errorString();
        return QVariantMap();
    }

    if (xml.tokenType() == QXmlStreamReader::NoToken)
        xml.readNext();

    if ((xml.tokenType() != QXmlStreamReader::StartDocument) &&
        (xml.tokenType() != QXmlStreamReader::StartElement)) {
        qWarning() << QObject::tr("unexpected XML tokenType %1 (%2)")
                      .arg(xml.tokenString()).arg(xml.tokenType());
        return QVariantMap();
    }

    QVariantMap map;
    if (xml.tokenType() == QXmlStreamReader::StartDocument) {
        map.insert(prefix + QLatin1String("DocumentEncoding"), xml.documentEncoding().toString());
        map.insert(prefix + QLatin1String("DocumentVersion"), xml.documentVersion().toString());
        map.insert(prefix + QLatin1String("StandaloneDocument"), xml.isStandaloneDocument());
    } else {
        if (!xml.namespaceUri().isEmpty())
            map.insert(prefix + QLatin1String("NamespaceUri"), xml.namespaceUri().toString());
        foreach (const QXmlStreamAttribute &attribute, xml.attributes()) {
            QVariantMap attributeMap;
            attributeMap.insert(QLatin1String("Value"), attribute.value().toString());
            if (!attribute.namespaceUri().isEmpty())
                attributeMap.insert(QLatin1String("NamespaceUri"), attribute.namespaceUri().toString());
            if (!attribute.prefix().isEmpty())
                attributeMap.insert(QLatin1String("Prefix"), attribute.prefix().toString());
            attributeMap.insert(QLatin1String("QualifiedName"), attribute.qualifiedName().toString());
            map.insert(prefix + attribute.name().toString(), attributeMap);
        }
    }

    QString str;
    QVariant recursed;
    for (xml.readNext(); (!xml.atEnd()) && (xml.tokenType() != QXmlStreamReader::EndElement)
          && (xml.tokenType() != QXmlStreamReader::EndDocument); xml.readNext()) {
        switch (xml.tokenType()) {
        case QXmlStreamReader::Characters:
        case QXmlStreamReader::Comment:
        case QXmlStreamReader::DTD:
        case QXmlStreamReader::EntityReference:
            str = xml.text().toString().trimmed();
            if( str.length() > 0 )
                map.insert(prefix + xml.tokenString(), str);
            break;
        case QXmlStreamReader::ProcessingInstruction:
            map.insert(prefix + xml.processingInstructionTarget().toString(),
                            xml.processingInstructionData().toString());
            break;
        case QXmlStreamReader::StartElement:
            str = xml.name().toString();
            recursed = xmlStreamToVariant(xml, prefix, maxDepth-1);
            if( !map.contains(str) )
            {
                map.insert(str, recursed);
                break;
            }

#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
            if( map.value(str).type() != QVariant::List )
#else
            if( map.value(str).typeId() != QVariant::List )
#endif
            {
                QVariantList vals;
                vals.append(map.value(str));
                vals.append(recursed);
                map.insert(str, vals);
            } else {
                QVariantList vals = map.value(str).toList();
                vals.append(recursed);
                map.insert(str, vals);
            }
            break;
        case QXmlStreamReader::EndDocument:
            return map;
        default:
            qWarning() << QObject::tr("unexpected XML tokenType %1 (%2)")
                          .arg(xml.tokenString()).arg(xml.tokenType());
        }
    }

    return map;
}
