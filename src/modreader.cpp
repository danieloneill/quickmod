#include "modreader.h"

#include <QDebug>
#include <QFile>

#include "file.h"

ModReader::ModReader(File *file)
    : QObject{file},
      m_file(file)
{

}

bool ModReader::readZString(QIODevice &f, QString *dest)
{
    quint16 length = 0;
    if( 2 != f.read( (char*)&length, 2 ) )
        return false;

    if( length > 512 )
    {
        qDebug() << "Got length" << length << "in CNAM record..?";
        return false;
    }

    char label[513];
    label[512] = label[0] = '\0';
    if( length != f.read( label, length ) )
        return false;

    *dest = QString::fromUtf8(label);

    return true;
}

QVariant ModReader::readSkyrimMod(const QString &inPath)
{
    QVariantMap result;

    QString path = m_file->resolveCase(inPath);

    QFile f(path);
    if( !f.open(QIODevice::ReadOnly) )
        return false;

    struct {
        char    type[4];
        quint32 size;
        quint32 flags;
        quint32 formId;
        quint16 timestamp;
        quint16 versionControlInfo;
        quint16 internalVersion;
        quint16 unk1;
    } s_record;

    if( sizeof(s_record) != f.read( (char*)&s_record, sizeof(s_record) ) )
        return false;

    //qDebug() << "Record:" << s_record.type[0] << s_record.type[1] << s_record.type[2] << s_record.type[3] << s_record.size << s_record.flags << s_record.formId;
    if( s_record.type[0] != 'T' || s_record.type[1] != 'E' || s_record.type[2] != 'S' || s_record.type[3] != '4' )
        return false;

    QVariantMap flags;
    if( s_record.flags & 1 )
        flags["master"] = true;
    if( s_record.flags & 0x80 )
        flags["localised"] = true;
    if( s_record.flags & 0x200 )
        flags["light"] = true;
    if( s_record.flags & 0x40000 )
        flags["compressed"] = true;

    result["flags"] = flags;

    struct {
        char    type[4];
        quint16 size;
    } s_field;

    if( sizeof(s_field) != f.read( (char*)&s_field, sizeof(s_field) ) )
        return false;

    if( s_field.type[0] != 'H' || s_field.type[1] != 'E' || s_field.type[2] != 'D' || s_field.type[3] != 'R' )
        return false;
    //qDebug() << "Field:" << s_field.type[0] << s_field.type[1] << s_field.type[2] << s_field.type[3] << s_field.size;

    struct {
        float   version;
        quint32 recordCount;
        quint32 nextObjId;
    } s_header;

    if( sizeof(s_header) != f.read( (char*)&s_header, sizeof(s_header) ) )
        return false;

    //qDebug() << "Header:" << s_header.version << s_header.recordCount << s_header.nextObjId;

    QVariantList masters;

    bool done = false;
    do {
        char token[5] = { '\0', '\0', '\0', '\0', '\0' };
        quint16 length = 0;
        QString qlabel;

        if( 4 != f.read( token, 4 ) )
        {
            qDebug() << "Failed to read next header.";
            return false;
        }

        //printf("Token: %c%c%c%c\n", token[0], token[1], token[2], token[3]);

        if( token[0] == 'C' && token[1] == 'N' && token[2] == 'A' && token[3] == 'M' )
        {
            if( !readZString(f, &qlabel) )
                return false;

            result["author"] = qlabel;
        }
        else if( token[0] == 'S' && token[1] == 'N' && token[2] == 'A' && token[3] == 'M' )
        {
            if( !readZString(f, &qlabel) )
                return false;

            result["description"] = qlabel;
        }
        else if( token[0] == 'M' && token[1] == 'A' && token[2] == 'S' && token[3] == 'T' )
        {
            if( !readZString(f, &qlabel) )
                return false;

            // Read data, because:
            quint64 data;
            if( 4 != f.read( (char*)token, 4 ) )
                return false;

            if( 2 != f.read( (char*)&length, 2 ) )
                return false;

            //qDebug() << "data section is:" << length << "bytes";
            if( !f.read( (char*)&data, sizeof(quint64) ) )
                return false;

            // Got it
            masters.append( qlabel );
        } else
            done = true;
    } while( !done );

    if( masters.length() > 0 )
        result["masters"] = masters;

    return result;
}
