package mist.relgen.generate.generator

import java.util.ArrayList
import java.util.HashMap
import rdbms.Column
import rdbms.Database
import rdbms.ForeignKey
import rdbms.Table

/**
 * Generate Database create sql
 */
class SQLGenerator{

    var tables = new ArrayList<Table>();
    var tablesInv = new ArrayList<Table>();
    var count = -1;

	def initialize(Database db) {
	    count = db.tables.size;
	    while(count != 0) {
	        for (Table t : db.tables) {
                if(!tables.contains(t)) {
                    var b = true;
                    for (ForeignKey fk : t.tableFKs) {
                    	if(fk.refersTo != t) {
                    		b = b && tables.contains(fk.refersTo);
                    	}                        
                    }
                    if(b) {
                        count = count - 1;
                        tables.add(t);
                        tablesInv.add(0, t);                        
                    }    
                } 
            }
	    }	    
	}

    def generate(Database db) {
        initialize(db)
    '''
		«FOR t : tablesInv»
			«t.generateDrops»
		«ENDFOR»
		
		«FOR t : tables»
            «t.generate»
        «ENDFOR»

        «FOR t : tables»
        	«IF t.tableFKs.size > 0»
    			«t.generateAlter»
    		«ENDIF»
        «ENDFOR»
		
		«FOR t : tables»
			«FOR fk : t.tableFKs»
	    		«IF fk.inverseReferentialIntegrityCon»
	    			«fk.generateInverse()»
	    		«ENDIF»
			«ENDFOR»	
		«ENDFOR»		
    '''}
    
    def generateDrops(Table t) {
    '''
    	«FOR fk : t.tableFKs»
    		«IF fk.inverseReferentialIntegrityCon»
 				«fk.generateInverseDrop()»
    		«ENDIF»
		«ENDFOR»	
		DROP TABLE «fixName(t.name)»;
    '''}
    
    def generate(Table t) {
    '''
		CREATE TABLE «fixName(t.name)» (
			«FOR c : t.columns SEPARATOR ',' AFTER ','»«c.generate»«ENDFOR»
			CONSTRAINT «fixName(t.tablePK.name.toUpperCase)» PRIMARY KEY («FOR c : t.tablePK.PKandUQColumns SEPARATOR ', '»«fixName(c.name)»«ENDFOR»)
		);
    '''}
    
    def generate(Column c) {
    '''
		«fixName(c.name)» «IF c.columnDataType != null»«fixName(c.columnDataType.name)»«ELSE»varchar(30)«ENDIF»«IF c.length != 0»(«c.length»«IF c.precision != 0»,«c.precision»«ENDIF»)«ENDIF»«IF c.nullable == true» NULL «ELSE» NOT NULL «ENDIF»«IF c.^default != null » DEFAULT «c.^default» «ENDIF»
    '''}
    
    def generate(ForeignKey fk) {
    	//columns from the original table
    	var originalColumns = new ArrayList<String>();
    	for (Column c : fk.rhsKey.PKandUQColumns) {
    		originalColumns.add(fixName(c.name))
    	}
    	
    	//Columns in the new table (map them to a numbered hashmap)
    	var referencingColumnMap = new HashMap<Integer, String>();
    	for (Column c : fk.lhsAttr) {
    		for(var i = 0; i < originalColumns.size; i++) {
    			if (c.name.fixName.contains(originalColumns.get(i))) {
    				referencingColumnMap.put(i, c.name.fixName)
    			}
    		}
    	}
    	
    	//Columns in the new table
    	var referencingColumns = new ArrayList<String>();
    	for(var i = 0; i < originalColumns.size; i++) {
    		referencingColumns.add(referencingColumnMap.get(i))
    	}
    	
    '''
		CONSTRAINT «fixName(fk.name.toUpperCase())» FOREIGN KEY («FOR c : referencingColumns SEPARATOR ', '»«c»«ENDFOR») REFERENCES «fixName(fk.refersTo.name)» («FOR c : originalColumns SEPARATOR ', '»«c»«ENDFOR»)
    '''}
    
    def generateAlter(Table t) {
    '''
        ALTER TABLE «fixName(t.name)» ADD (
        	«FOR fk : t.tableFKs SEPARATOR ','»«fk.generate»«ENDFOR»
        );
    '''}
    
    def generateInverseDrop(ForeignKey fk) {
    	//preset the names
    	var constName = new String("IRI_"+fk.refersTo.name+"_"+fk.FKTable.name);
    	if (fixName(constName).length > 20) { 
			constName = fixName(constName).substring(0,20);
		} else {
			constName = fixName(constName);
		}
        var Ni = fixName(fk.FKTable.name)
        var Nj = fixName(fk.refersTo.name)
        var viewName = fixName("View_" + Nj + "_" + Ni)
    ''' 
    	DROP TRIGGER TRG_«Ni.substring(0,2)»_«constName»_U3;
    	DROP TRIGGER TRG_«Ni.substring(0,2)»_«constName»_U2;
    	DROP TRIGGER TRG_«Ni.substring(0,2)»_«constName»_U1;
    	DROP TRIGGER TRG_«Ni.substring(0,2)»_«constName»_D3;
    	DROP TRIGGER TRG_«Ni.substring(0,2)»_«constName»_D2;
    	DROP TRIGGER TRG_«Ni.substring(0,2)»_«constName»_D1;
    	DROP TRIGGER TRG_«constName»_View;
    	DROP VIEW «viewName»;
    	DROP PROCEDURE CascadeIRI_Del_«Ni»;
    	DROP FUNCTION ContainmentIRI_«Nj»;
    	DROP PACKAGE «constName»_PCK;
    '''} 
    
    def generateInverse(ForeignKey fk) {
    	//preset the names
        var constName = new String("IRI_"+fk.refersTo.name+"_"+fk.FKTable.name);
    	if (fixName(constName).length > 20) { 
			constName = fixName(constName).substring(0,20);
		} else {
			constName = fixName(constName);
		}
        var Ni = fixName(fk.FKTable.name)
        var Nj = fixName(fk.refersTo.name)
        var viewName = fixName("View_" + Nj + "_" + Ni)
        
        //to avoid duplicates populate list of columns
        var columns = new HashMap<String, ArrayList<String>>()
        var colNames = new ArrayList<String>()
        for(Column c : fk.FKTable.columns) {
        	colNames.add(fixName(c.name))
        }
        columns.put(Ni.toLowerCase, colNames)
        colNames = new ArrayList<String>()
        for(Column c : fk.refersTo.columns) {
        	if(!columns.get(Ni.toLowerCase).contains(fixName(c.name))) {
        		colNames.add(fixName(c.name))
        	}        		
        }
        columns.put(Nj.toLowerCase, colNames)
    ''' 
        CREATE OR REPLACE PACKAGE «constName»_PCK
        IS
            TYPE TRec«Ni» IS RECORD («FOR col : fk.FKTable.columns SEPARATOR ", "»«col.name» «Ni».«col.name»%TYPE«ENDFOR»);
            TYPE TTabForDelUpd IS TABLE OF TRec«Ni» INDEX BY BINARY_INTEGER;
            For_«Ni» TTabForDelUpd;
            Count_IRI NUMBER(8,0);
            Trigger_Ex BOOLEAN;
        END;
        /
        CREATE OR REPLACE FUNCTION ContainmentIRI_«Nj» (v IN «Nj»%ROWTYPE)
        RETURN BOOLEAN
        IS
            I NUMBER;
        BEGIN
            SELECT COUNT(*) INTO I FROM «Ni» u
                WHERE («FOR col : fk.rhsKey.PKandUQColumns SEPARATOR " and "»u.«col.name» = v.«col.name»«ENDFOR»);
            IF I <> 0 THEN
                RETURN TRUE;
            ELSE
                RETURN FALSE;
            END IF;
        END;
        /
        CREATE OR REPLACE PROCEDURE CascadeIRI_Del_«Ni» (u IN «Ni»%ROWTYPE)
        IS
        BEGIN
            DELETE FROM «Nj» v WHERE («FOR col : fk.refersTo.tablePK.PKandUQColumns SEPARATOR " and "»v.«col.name» = u.«col.name»«ENDFOR»);
        END;
        /
        CREATE OR REPLACE VIEW «viewName» AS
            SELECT «FOR col : columns.get(Ni.toLowerCase) SEPARATOR ','» «Ni.toLowerCase».«col»«ENDFOR»«FOR col : columns.get(Nj.toLowerCase) BEFORE ',' SEPARATOR ','» «Nj.toLowerCase».«col»«ENDFOR»
            FROM «Nj» «Nj.toLowerCase()» JOIN «Ni» «Ni.toLowerCase()» ON «FOR col : fk.refersTo.tablePK.PKandUQColumns SEPARATOR " and "»«Nj.toLowerCase()».«col.name» = «Ni.toLowerCase()».«col.name»«ENDFOR»;
        /
        CREATE OR REPLACE TRIGGER TRG_«constName»_View
        INSTEAD OF INSERT ON «viewName»
        FOR EACH ROW
        DECLARE
            I NUMBER;
            Exc EXCEPTION;
            t «Nj»%ROWTYPE;
        BEGIN
            SELECT COUNT(*) INTO I 
                FROM «Nj» 
                WHERE («FOR col : fk.refersTo.tablePK.PKandUQColumns SEPARATOR " and "»«col.name» = :NEW.«col.name»«ENDFOR»);
            IF I <> 0 THEN
                INSERT INTO «Ni» («FOR col : fk.FKTable.columns SEPARATOR ", "»«col.name»«ENDFOR») VALUES («FOR col : fk.FKTable.columns SEPARATOR ", "»:NEW.«col.name»«ENDFOR»);
            ELSE
                «constName»_PCK.Trigger_Ex := FALSE;
                INSERT INTO «Nj» («FOR col : fk.refersTo.columns SEPARATOR ", "»«col.name»«ENDFOR») VALUES («FOR col : fk.refersTo.columns SEPARATOR ", "»:NEW.«col.name»«ENDFOR»);
                INSERT INTO «Ni» («FOR col : fk.FKTable.columns SEPARATOR ", "»«col.name»«ENDFOR») VALUES («FOR col : fk.FKTable.columns SEPARATOR ", "»:NEW.«col.name»«ENDFOR»);
                «constName»_PCK.Trigger_Ex := TRUE;
                SELECT * INTO t
                    FROM «Nj» WHERE («FOR col : fk.refersTo.columns SEPARATOR " and "»«col.name» = :NEW.«col.name»«ENDFOR»);
                IF NOT ContainmentIRI_«Nj»(t) THEN
                    RAISE Exc;
                END IF;
            END IF;
            EXCEPTION WHEN Exc THEN
                RAISE_APPLICATION_ERROR (-20001,'IRIC violation!');
        END;
        /
        CREATE OR REPLACE TRIGGER TRG_«Ni.substring(0,2)»_«constName»_D1
        BEFORE DELETE ON «Ni»
        BEGIN
            «constName»_PCK.Count_IRI := 0;
            «constName»_PCK.For_«Ni».DELETE;
        END;
        /
        CREATE OR REPLACE TRIGGER TRG_«Ni.substring(0,2)»_«constName»_D2
        BEFORE DELETE ON «Ni»
        FOR EACH ROW
        DECLARE
            u «Ni»%ROWTYPE;
        BEGIN
            «FOR col : fk.FKTable.columns»
            u.«col.name» := :OLD.«col.name»;
            «ENDFOR»
            «constName»_PCK.Count_IRI := «constName»_PCK.Count_IRI + 1;
            «FOR col : fk.FKTable.columns»
            «constName»_PCK.For_«Ni» («constName»_PCK.Count_IRI).
                    «col.name» := u.«col.name»;
            «ENDFOR»
        END;
        /
        CREATE OR REPLACE TRIGGER TRG_«Ni.substring(0,2)»_«constName»_D3
        AFTER DELETE ON «Ni»
        DECLARE
            u «Ni»%ROWTYPE;
            I NUMBER;
        BEGIN
            FOR j IN 1.. «constName»_PCK.Count_IRI LOOP
                «FOR col : fk.FKTable.columns»
                u.«col.name» := «constName»_PCK.For_«Ni» (j).«col.name»;
                «ENDFOR»
                SELECT COUNT(*) INTO I FROM «Nj»
                    WHERE («FOR col : fk.refersTo.tablePK.PKandUQColumns SEPARATOR " and "»«col.name» = u.«col.name»«ENDFOR»);
                IF I <> 0 THEN
                    CascadeIRI_Del_«Ni»(u);
                END IF;
            END LOOP;
        END;
        /        
        CREATE OR REPLACE TRIGGER TRG_«Ni.substring(0,2)»_«constName»_U1
        BEFORE UPDATE ON «Ni»
        BEGIN
            «constName»_PCK.Count_IRI := 0;
            «constName»_PCK.For_«Ni».DELETE;
        END;
        /
        CREATE OR REPLACE TRIGGER TRG_«Ni.substring(0,2)»_«constName»_U2
        BEFORE UPDATE ON «Ni»
        FOR EACH ROW
        WHEN («FOR col : fk.FKTable.columns SEPARATOR " or "»NEW.«col.name» <> OLD.«col.name»«ENDFOR»)
        DECLARE
            u «Ni»%ROWTYPE;
        BEGIN
            «FOR col : fk.FKTable.columns»
            u.«col.name» := :OLD.«col.name»;
            «ENDFOR»
            «constName»_PCK.Count_IRI := «constName»_PCK.Count_IRI + 1;
            «FOR col : fk.FKTable.columns»
            «constName»_PCK.For_«Ni» («constName»_PCK.Count_IRI).
                    «col.name» := u.«col.name»;
            «ENDFOR»
        END;
        /
        CREATE OR REPLACE TRIGGER TRG_«Ni.substring(0,2)»_«constName»_U3
        AFTER UPDATE ON «Ni»
        DECLARE
            u «Ni»%ROWTYPE;
            I NUMBER;
        BEGIN
            FOR j IN 1..«constName»_PCK.Count_IRI LOOP
                «FOR col : fk.FKTable.columns»
                u.«col.name» := «constName»_PCK.For_«Ni» (j).«col.name»;
                «ENDFOR»
                SELECT COUNT(*) INTO I FROM «Nj» 
                    WHERE («FOR col : fk.refersTo.tablePK.PKandUQColumns SEPARATOR " and "»«col.name» = u.«col.name»«ENDFOR»);
                IF I <> 0 THEN
                    RAISE_APPLICATION_ERROR (-20002,'Tuple modification is forbidden «Ni»');
                END IF;
            END LOOP;
        END;
        /
    '''}    
    
    def fixName(String name) {
    	var reservedWords = "ALL,ALTER,AND,ANY,ARRAY,ARROW,AS,ASC,AT,BEGIN,BETWEEN,BY,CASE,CHECK,CLUSTERS,CLUSTER,COLAUTH,COLUMNS,COMPRESS,CONNECT,CRASH,CREATE,CURRENT,DECIMAL,DECLARE,DEFAULT,DELETE,DESC,DISTINCT,DROP,ELSE,END,EXCEPTION,EXCLUSIVE,EXISTS,FETCH,FORM,FOR,FROM,GOTO,GRANT,GROUP,HAVING,IDENTIFIED,IF,IN,INDEXES,INDEX,INSERT,INTERSECT,INTO,IS,LIKE,LOCK,MINUS,MODE,NOCOMPRESS,NOT,NOWAIT,NULL,OF,ON,OPTION,OR,ORDER,OVERLAPS,PRIOR,PROCEDURE,PUBLIC,RANGE,RECORD,RESOURCE,REVOKE,SELECT,SHARE,SIZE,SQL,START,SUBTYPE,TABAUTH,TABLE,THEN,TO,TYPE,UNION,UNIQUE,UPDATE,USE,VALUES,VIEW,VIEWS,WHEN,WHERE,WITH";
		var keyWords = "A,ADD,AGENT,AGGREGATE,ARRAY,ATTRIBUTE,AUTHID,AVG,BFILE_BASE,BINARY,BLOB_BASE,BLOCK,BODY,BOTH,BOUND,BULK,BYTE ,C,CALL,CALLING,CASCADE,CHAR,CHAR_BASE,CHARACTER,CHARSETFORM,CHARSETID,CHARSET,CLOB_BASE,CLOSE,COLLECT,COMMENT,COMMIT,COMMITTED,COMPILED,CONSTANT,CONSTRUCTOR,CONTEXT,CONVERT,COUNT,CURSOR,CUSTOMDATUM,DANGLING,DATA,DATE,DATE_BASE,DAY,DEFINE,DETERMINISTIC,DOUBLE,DURATION,ELEMENT,ELSIF,EMPTY,ESCAPE,EXCEPT,EXCEPTIONS,EXECUTE,EXIT,EXTERNAL,FINAL,FIXED,FLOAT,FORALL,FORCE,FUNCTION,GENERAL,HASH,HEAP,HIDDEN,HOUR,IMMEDIATE,INCLUDING,INDICATOR,INDICES,INFINITE,INSTANTIABLE,INT,INTERFACE,INTERVAL,INVALIDATE,ISOLATION,JAVA,LANGUAGE,LARGE,LEADING,LENGTH,LEVEL,LIBRARY,LIKE2,LIKE4,LIKEC,LIMIT,LIMITED,LOCAL,LONG,LOOP,MAP,MAX,MAXLEN,MEMBER,MERGE,MIN,MINUTE,MOD,MODIFY,MONTH,MULTISET,NAME,NAN,NATIONAL,NATIVE,NCHAR,NEW,NOCOPY,NUMBER_BASE,OBJECT,OCICOLL,OCIDATETIME,OCIDATE,OCIDURATION,OCIINTERVAL,OCILOBLOCATOR,OCINUMBER,OCIRAW,OCIREFCURSOR,OCIREF,OCIROWID,OCISTRING,OCITYPE,ONLY,OPAQUE,OPEN,OPERATOR,ORACLE,ORADATA,ORGANIZATION,ORLANY,ORLVARY,OTHERS,OUT,OVERRIDING,PACKAGE,PARALLEL_ENABLE,PARAMETER,PARAMETERS,PARTITION,PASCAL,PIPE,PIPELINED,PRAGMA,PRECISION,PRIVATE,RAISE,RANGE,RAW,READ,RECORD,REF,REFERENCE,REM,REMAINDER,RENAME,RESULT,RETURN,RETURNING,REVERSE,ROLLBACK,ROW,SAMPLE,SAVE,SAVEPOINT,SB1,SB2,SB4,SECOND,SEGMENT,SELF,SEPARATE,SEQUENCE,SERIALIZABLE,SET,SHORT,SIZE_T,SOME,SPARSE,SQLCODE,SQLDATA,SQLNAME,SQLSTATE,STANDARD,STATIC,STDDEV,STORED,STRING,STRUCT,STYLE,SUBMULTISET,SUBPARTITION,SUBSTITUTABLE,SUBTYPE,SUM,SYNONYM,TDO,THE,TIME,TIMESTAMP,TIMEZONE_ABBR,TIMEZONE_HOUR,TIMEZONE_MINUTE,TIMEZONE_REGION,TRAILING,TRANSAC,TRANSACTIONAL,TRUSTED,TYPE,UB1,UB2,UB4,UNDER,UNSIGNED,UNTRUSTED,USE,USING,VALIST,VALUE,VARIABLE,VARIANCE,VARRAY,VARYING,VOID,WHILE,WORK,WRAPPED,WRITE,YEAR,ZONE";
    	var reservedWordSplit = reservedWords.split(",").toList;
    	var keyWordsSplit = keyWords.split(",").toList;
    	var retName = name;
    	if(name.length >= 30) {
    		retName = name.substring(0,30);
    	} 
    	
    	if(reservedWordSplit.contains(retName) || keyWordsSplit.contains(retName)) {
    		retName = '_' + retName;
    	}
    	return retName;
    } 	
}