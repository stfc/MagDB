--
-- PostgreSQL database dump
--

-- Dumped from database version 9.0.13
-- Dumped by pg_dump version 9.1.9
-- Started on 2013-08-14 17:36:33 BST

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

--
-- TOC entry 879 (class 2612 OID 11574)
-- Name: plpgsql; Type: PROCEDURAL LANGUAGE; Schema: -; Owner: -
--

CREATE OR REPLACE PROCEDURAL LANGUAGE plpgsql;


SET search_path = public, pg_catalog;

--
-- TOC entry 289 (class 1255 OID 24441)
-- Dependencies: 6 879
-- Name: addarchivesystemstable(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION addarchivesystemstable() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

	DECLARE
	  machine_name character varying(255);
	  machine_domain character varying(64);
	  vcastor_row RECORD;
        BEGIN
	   SELECT "name" INTO machine_name FROM "vSystemNames" WHERE "systemId" = OLD."systemId";
	   SELECT "domainName" INTO machine_domain FROM "vSystemNames" WHERE "systemId" = OLD."systemId";

	   SELECT * INTO vcastor_row FROM "vCastor" WHERE "machineName" = machine_name;
        
	   IF ( TG_OP = 'UPDATE' ) THEN
		INSERT INTO "storageSystemArchives" (
		    "archiveReason",
		    "lastUpdatedBy",
		    "lastUpdateDate",
		    "storageSystemId",
		    "machineName",
		    "currentStatus",
		    "normalStatus",
		    "currentTeam",
		    "serviceType",
		    "virtualOrganisation",
		    "diskPool",
		    "sizeTb",
		    "numberFilesystems",
		    "isPuppetManaged",
		    "isQuattorManaged",
		    "isYaimManaged",
		    "miscComments")
		VALUES (
		    TG_OP,
		    NEW."lastUpdatedBy",
		    now(),
		    OLD.id,
		    (machine_name::text || '.'::text) || machine_domain::text,
		    vcastor_row."currentStatus",
		    vcastor_row."normalStatus",
		    vcastor_row."currentTeam",
		    vcastor_row."serviceType",
		    vcastor_row."virtualOrganisation",
		    vcastor_row."diskPool",
		    vcastor_row."sizeTb",
		    vcastor_row."numberFileSystems",
		    vcastor_row."puppetManaged",
		    vcastor_row."quattorManaged",
		    OLD."isYaimManaged",
		    vcastor_row."miscComments" );	
		RETURN NEW;
	    ELSIF ( TG_OP = 'DELETE' ) THEN
		INSERT INTO "storageSystemArchives" (
		    "archiveReason",
		    "lastUpdatedBy",
		    "lastUpdateDate",
		    "storageSystemId",
		    "machineName",
		    "currentStatus",
		    "normalStatus",
		    "currentTeam",
		    "serviceType",
		    "virtualOrganisation",
		    "diskPool",
		    "sizeTb",
		    "numberFilesystems",
		    "isPuppetManaged",
		    "isQuattorManaged",
		    "isYaimManaged",
		    "miscComments")
		VALUES (
		    TG_OP,
		    OLD."lastUpdatedBy",
		    now(),
		    OLD.id,
		    (machine_name::text || '.'::text) || machine_domain::text,
		    vcastor_row."currentStatus",
		    vcastor_row."normalStatus",
		    vcastor_row."currentTeam",
		    vcastor_row."serviceType",
		    vcastor_row."virtualOrganisation",
		    vcastor_row."diskPool",
		    vcastor_row."sizeTb",
		    vcastor_row."numberFileSystems",
		    vcastor_row."puppetManaged",
		    vcastor_row."quattorManaged",
		    OLD."isYaimManaged",
		    vcastor_row."miscComments" );	
		RETURN OLD;
	    END IF;	
END;
$$;


--
-- TOC entry 280 (class 1255 OID 24465)
-- Dependencies: 6 879
-- Name: checkequalcastorinstanceid(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION checkequalcastorinstanceid() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
     DECLARE
        dCastor INTEGER;
        voCastor INTEGER;
     BEGIN
        SELECT "castorInstanceId" INTO dCastor FROM "diskPools" WHERE id = NEW."diskPoolId";
        SELECT "castorInstanceId" INTO voCastor FROM "virtualOrganisations" WHERE id = NEW."virtualOrganisationId";
      
      IF dCastor != voCastor THEN
         RAISE EXCEPTION 'diskPool.castorInstanceId must be the same as virtualOrganisation.castorInstanceId';
      END IF;
      
      RETURN NEW;
    END;
$$;


--
-- TOC entry 276 (class 1255 OID 24457)
-- Dependencies: 6 879
-- Name: checkgateway(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION checkgateway() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
     BEGIN
        IF NEW."gateway" <<= NEW."ipAddress" THEN
	   RETURN NEW;
	ELSE
	   RAISE EXCEPTION 'Wrong gateway';
	END IF;
    END;
$$;


--
-- TOC entry 282 (class 1255 OID 24453)
-- Dependencies: 879 6
-- Name: checkhostaddress(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION checkhostaddress() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
     DECLARE
        subnet RECORD;
     BEGIN
        FOR subnet IN SELECT * FROM "networkSubnets" LOOP
           IF NEW."ipAddress" <<= subnet."ipAddress" THEN
                 IF NEW."ipAddress" = subnet."gateway" THEN
                    RAISE EXCEPTION 'This a gateway address';
                 END IF;
	      NEW."networkSubnetId" := subnet."id";
	      RETURN NEW;
	   END IF;
        END LOOP;
        RAISE EXCEPTION 'This IP address is wrong';
    END;
$$;


--
-- TOC entry 279 (class 1255 OID 24459)
-- Dependencies: 879 6
-- Name: checkipaddress(integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION checkipaddress(host_id integer, subnet_id integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
      DECLARE
        subnet RECORD;
        host RECORD;
      BEGIN
        SELECT * INTO host FROM "hostAddresses" WHERE id = host_id;
        
        FOR subnet IN SELECT * FROM "networkSubnets" WHERE id != subnet_id LOOP
           IF host."ipAddress" <<= subnet."ipAddress" THEN
              IF host."ipAddress" != subnet."gateway" THEN
                 host."newtorkSubnetId" := subnet."id";
                 RETURN TRUE;
              END IF;
	   END IF;
        END LOOP;
        RETURN FALSE;
      END;
$$;


--
-- TOC entry 283 (class 1255 OID 24460)
-- Dependencies: 879 6
-- Name: checknewnetworkaddress(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION checknewnetworkaddress() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
     DECLARE
        host RECORD;
     BEGIN
        IF (OLD."ipAddress" <<= NEW."ipAddress" AND OLD."gateway" = NEW."gateway") THEN
	   RETURN NEW;
	END IF;


        FOR host IN SELECT * FROM "hostAddresses" WHERE "networkSubnetId" = NEW."id" LOOP
           IF (NOT(host."ipAddress" <<= NEW."ipAddress" AND host."ipAddress" != NEW."gateway") AND NOT(checkIpAddress(host."id",NEW."id"))) THEN
              RAISE EXCEPTION 'You cannot change network address';
	   END IF;
        END LOOP;
	RETURN NEW;
    END;
$$;


--
-- TOC entry 284 (class 1255 OID 24439)
-- Dependencies: 6 879
-- Name: checkrackunits(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION checkrackunits() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
      DECLARE
	 rack_model_units SMALLINT;
         rack_model_id INTEGER;
      BEGIN
         SELECT "rackModelId" INTO rack_model_id FROM racks WHERE id = NEW."rackId";
         SELECT "rackModelUnits" INTO rack_model_units FROM "rackModels" WHERE id = rack_model_id;

         IF rack_model_units < NEW."systemRackUnits" OR rack_model_units < NEW."systemRackPos" THEN
	    RAISE EXCEPTION 'Bad number of systemRackUnits or systemRackPos';
         END IF;
         RETURN NEW;
      END;
$$;


--
-- TOC entry 281 (class 1255 OID 24437)
-- Dependencies: 6 879
-- Name: checkrowscols(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION checkrowscols() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
      DECLARE
	 room_rows SMALLINT;
	 room_cols SMALLINT;
      BEGIN
         SELECT "roomRows" INTO room_rows FROM rooms WHERE id = NEW."roomId";
         SELECT "roomCols" INTO room_cols FROM rooms WHERE id = NEW."roomId";

         IF room_rows < NEW."rackRow" OR room_cols < NEW."rackCol" THEN
	    RAISE EXCEPTION 'Bad number of rackRow or rackCol';
         END IF;
         RETURN NEW;
      END;
$$;


--
-- TOC entry 285 (class 1255 OID 24462)
-- Dependencies: 6 879
-- Name: checkunchagedcastorinstanceid(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION checkunchagedcastorinstanceid() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
     BEGIN
      IF NEW."castorInstanceId" != OLD."castorInstanceId" THEN
         RAISE EXCEPTION 'You cannot change castorInstanceId';
      END IF;
      RETURN NEW;
    END;
$$;


--
-- TOC entry 286 (class 1255 OID 24443)
-- Dependencies: 6 879
-- Name: checkuniquesystemid(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION checkuniquesystemid() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
      DECLARE
	 number_of_systems INTEGER;
	 result INTEGER;
      BEGIN
         number_of_systems := 0;
         result := 0;
         
         SELECT COUNT(*) INTO number_of_systems FROM "storageSystems" WHERE "systemId" = NEW."systemId";
         result := result + number_of_systems;

         SELECT COUNT(*) INTO number_of_systems FROM "headNodes" WHERE "systemId" = NEW."systemId";
         result := result + number_of_systems;

         SELECT COUNT(*) INTO number_of_systems FROM "tapeServers" WHERE "systemId" = NEW."systemId";
         result := result + number_of_systems;
 
         SELECT COUNT(*) INTO number_of_systems FROM "databaseServers" WHERE "systemId" = NEW."systemId";
         result := result + number_of_systems;
                 
         IF result != 0 THEN
	    RAISE EXCEPTION 'This system ID is already in use';
         END IF;
         RETURN NEW;
      END;
$$;


--
-- TOC entry 287 (class 1255 OID 24448)
-- Dependencies: 879 6
-- Name: checkuniquesystemid2(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION checkuniquesystemid2() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
      DECLARE
	 number_of_systems INTEGER;
	 result INTEGER;
      BEGIN
         number_of_systems := 0;
         result := 0;
         
         SELECT COUNT(*) INTO number_of_systems FROM "storageSystems" WHERE "systemId" = NEW."systemId";
         result := result + number_of_systems;

         SELECT COUNT(*) INTO number_of_systems FROM "headNodes" WHERE "systemId" = NEW."systemId";
         result := result + number_of_systems;

         SELECT COUNT(*) INTO number_of_systems FROM "tapeServers" WHERE "systemId" = NEW."systemId";
         result := result + number_of_systems;
 
         SELECT COUNT(*) INTO number_of_systems FROM "databaseServers" WHERE "systemId" = NEW."systemId";
         result := result + number_of_systems;
                 
         IF result != 0 THEN
	    RAISE EXCEPTION 'This system ID is already in use';
         END IF;
         RETURN NEW;
      END;
$$;


--
-- TOC entry 288 (class 1255 OID 24498)
-- Dependencies: 879 6
-- Name: deletealiases(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION deletealiases() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
     DECLARE
        host RECORD;
     BEGIN
	DELETE FROM "aliases" WHERE "id" = OLD."aliasId";
	RETURN OLD;
    END;
$$;


--
-- TOC entry 277 (class 1255 OID 24467)
-- Dependencies: 6 879
-- Name: settimestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION settimestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	NEW."lastUpdateDate" := now();
	RETURN NEW;
END;
$$;


--
-- TOC entry 278 (class 1255 OID 24455)
-- Dependencies: 879 6
-- Name: vaildemailaddress(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION vaildemailaddress() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
     DECLARE
        pos INTEGER;
     BEGIN
        pos := position('@' in NEW."vendorEmailAddress");
        IF pos = 0 THEN
	    RAISE EXCEPTION 'Wrong email address';
        END IF;
        RETURN NEW;
    END;
$$;


SET default_tablespace = '';

SET default_with_oids = false;

--
-- TOC entry 183 (class 1259 OID 24072)
-- Dependencies: 2330 2331 2332 2333 6
-- Name: admins; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE admins (
    id integer NOT NULL,
    "commonName" character varying(64) NOT NULL,
    "countryName" character varying(16) DEFAULT 'UK'::character varying NOT NULL,
    organisation character varying(16) DEFAULT 'eScience'::character varying NOT NULL,
    "organisationalUnit" character varying(16) DEFAULT 'CLRC'::character varying NOT NULL,
    location character varying(16) DEFAULT 'RAL'::character varying NOT NULL,
    "teamId" integer NOT NULL
);


--
-- TOC entry 2629 (class 0 OID 0)
-- Dependencies: 183
-- Name: TABLE admins; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE admins IS 'List of admins with fullname country and location.';


--
-- TOC entry 182 (class 1259 OID 24070)
-- Dependencies: 183 6
-- Name: admins_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE admins_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2630 (class 0 OID 0)
-- Dependencies: 182
-- Name: admins_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE admins_id_seq OWNED BY admins.id;


--
-- TOC entry 209 (class 1259 OID 24331)
-- Dependencies: 2375 2376 6
-- Name: aliases; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE aliases (
    "lastUpdatedBy" character varying(64) DEFAULT 'Deployment'::character varying NOT NULL,
    "lastUpdateDate" timestamp without time zone DEFAULT now() NOT NULL,
    id integer NOT NULL,
    name character varying(64) NOT NULL,
    "domainId" integer NOT NULL
);


--
-- TOC entry 2631 (class 0 OID 0)
-- Dependencies: 209
-- Name: TABLE aliases; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE aliases IS 'DNS aliases for various systems.';


--
-- TOC entry 208 (class 1259 OID 24329)
-- Dependencies: 209 6
-- Name: aliases_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE aliases_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2632 (class 0 OID 0)
-- Dependencies: 208
-- Name: aliases_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE aliases_id_seq OWNED BY aliases.id;


--
-- TOC entry 173 (class 1259 OID 24005)
-- Dependencies: 2310 2311 6
-- Name: castorInstances; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "castorInstances" (
    "lastUpdatedBy" character varying(64) DEFAULT 'Deployment'::character varying NOT NULL,
    "lastUpdateDate" timestamp without time zone DEFAULT now() NOT NULL,
    id integer NOT NULL,
    "castorInstanceName" character varying(16) NOT NULL
);


--
-- TOC entry 172 (class 1259 OID 24003)
-- Dependencies: 173 6
-- Name: castorInstances_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "castorInstances_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2633 (class 0 OID 0)
-- Dependencies: 172
-- Name: castorInstances_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "castorInstances_id_seq" OWNED BY "castorInstances".id;


--
-- TOC entry 148 (class 1259 OID 23793)
-- Dependencies: 2276 2277 6
-- Name: categories; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE categories (
    "lastUpdatedBy" character varying(64) DEFAULT 'Deployment'::character varying NOT NULL,
    "lastUpdateDate" timestamp without time zone DEFAULT now() NOT NULL,
    id integer NOT NULL,
    "categoryName" character varying(32) NOT NULL,
    description character varying(250)
);


--
-- TOC entry 2634 (class 0 OID 0)
-- Dependencies: 148
-- Name: TABLE categories; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE categories IS 'Table of categories, these map to system types in terms of hardware in Quattor.';


--
-- TOC entry 147 (class 1259 OID 23791)
-- Dependencies: 6 148
-- Name: categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2635 (class 0 OID 0)
-- Dependencies: 147
-- Name: categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE categories_id_seq OWNED BY categories.id;


--
-- TOC entry 201 (class 1259 OID 24269)
-- Dependencies: 2365 2366 6
-- Name: databaseServers; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "databaseServers" (
    "lastUpdatedBy" character varying(64) DEFAULT 'Deployment'::character varying NOT NULL,
    "lastUpdateDate" timestamp without time zone DEFAULT now() NOT NULL,
    id integer NOT NULL,
    "systemId" integer NOT NULL,
    "databaseTypeId" integer NOT NULL
);


--
-- TOC entry 200 (class 1259 OID 24267)
-- Dependencies: 201 6
-- Name: databaseServers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "databaseServers_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2636 (class 0 OID 0)
-- Dependencies: 200
-- Name: databaseServers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "databaseServers_id_seq" OWNED BY "databaseServers".id;


--
-- TOC entry 199 (class 1259 OID 24259)
-- Dependencies: 6
-- Name: databaseTypes; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "databaseTypes" (
    id integer NOT NULL,
    name character varying(255) NOT NULL
);


--
-- TOC entry 198 (class 1259 OID 24257)
-- Dependencies: 199 6
-- Name: databaseTypes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "databaseTypes_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2637 (class 0 OID 0)
-- Dependencies: 198
-- Name: databaseTypes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "databaseTypes_id_seq" OWNED BY "databaseTypes".id;


--
-- TOC entry 175 (class 1259 OID 24017)
-- Dependencies: 2313 2314 2316 2317 2318 2319 6
-- Name: diskPools; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "diskPools" (
    "lastUpdatedBy" character varying(64) DEFAULT 'Deployment'::character varying NOT NULL,
    "lastUpdateDate" timestamp without time zone DEFAULT now() NOT NULL,
    id integer NOT NULL,
    "diskPoolName" character varying(32) NOT NULL,
    "castorInstanceId" integer NOT NULL,
    "diskNum" smallint DEFAULT 0 NOT NULL,
    "tapeNum" smallint DEFAULT 0 NOT NULL,
    CONSTRAINT "diskPools_diskNum_check" CHECK ((("diskNum" >= 0) AND ("diskNum" <= 2))),
    CONSTRAINT "diskPools_tapeNum_check" CHECK ((("tapeNum" >= 0) AND ("tapeNum" <= 2)))
);


--
-- TOC entry 174 (class 1259 OID 24015)
-- Dependencies: 6 175
-- Name: diskPools_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "diskPools_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2638 (class 0 OID 0)
-- Dependencies: 174
-- Name: diskPools_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "diskPools_id_seq" OWNED BY "diskPools".id;


--
-- TOC entry 205 (class 1259 OID 24302)
-- Dependencies: 2369 2370 6
-- Name: domains; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE domains (
    "lastUpdatedBy" character varying(64) DEFAULT 'Deployment'::character varying NOT NULL,
    "lastUpdateDate" timestamp without time zone DEFAULT now() NOT NULL,
    id integer NOT NULL,
    "domainName" character varying(32) NOT NULL
);


--
-- TOC entry 204 (class 1259 OID 24300)
-- Dependencies: 6 205
-- Name: domains_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE domains_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2639 (class 0 OID 0)
-- Dependencies: 204
-- Name: domains_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE domains_id_seq OWNED BY domains.id;


--
-- TOC entry 195 (class 1259 OID 24217)
-- Dependencies: 6
-- Name: functionTypes; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "functionTypes" (
    id integer NOT NULL,
    name character varying(255) NOT NULL
);


--
-- TOC entry 2640 (class 0 OID 0)
-- Dependencies: 195
-- Name: TABLE "functionTypes"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE "functionTypes" IS 'currently empty';


--
-- TOC entry 194 (class 1259 OID 24215)
-- Dependencies: 6 195
-- Name: functionTypes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "functionTypes_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2641 (class 0 OID 0)
-- Dependencies: 194
-- Name: functionTypes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "functionTypes_id_seq" OWNED BY "functionTypes".id;


--
-- TOC entry 160 (class 1259 OID 23868)
-- Dependencies: 6
-- Name: hardwareModelAttributeTypes; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "hardwareModelAttributeTypes" (
    id integer NOT NULL,
    "typeName" character varying(32) NOT NULL
);


--
-- TOC entry 159 (class 1259 OID 23866)
-- Dependencies: 160 6
-- Name: hardwareModelAttributeTypes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "hardwareModelAttributeTypes_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2642 (class 0 OID 0)
-- Dependencies: 159
-- Name: hardwareModelAttributeTypes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "hardwareModelAttributeTypes_id_seq" OWNED BY "hardwareModelAttributeTypes".id;


--
-- TOC entry 162 (class 1259 OID 23878)
-- Dependencies: 2293 2294 6
-- Name: hardwareModelAttributes; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "hardwareModelAttributes" (
    "lastUpdatedBy" character varying(64) DEFAULT 'Deployment'::character varying NOT NULL,
    "lastUpdateDate" timestamp without time zone DEFAULT now() NOT NULL,
    id integer NOT NULL,
    "hardwareModelAttributeTypeId" integer NOT NULL,
    value character varying(64) NOT NULL,
    "hardwareModelId" integer NOT NULL
);


--
-- TOC entry 161 (class 1259 OID 23876)
-- Dependencies: 6 162
-- Name: hardwareModelAttributes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "hardwareModelAttributes_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2643 (class 0 OID 0)
-- Dependencies: 161
-- Name: hardwareModelAttributes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "hardwareModelAttributes_id_seq" OWNED BY "hardwareModelAttributes".id;


--
-- TOC entry 156 (class 1259 OID 23838)
-- Dependencies: 6
-- Name: hardwareModelClasses; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "hardwareModelClasses" (
    id integer NOT NULL,
    "className" character varying(16) NOT NULL
);


--
-- TOC entry 155 (class 1259 OID 23836)
-- Dependencies: 6 156
-- Name: hardwareModelClasses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "hardwareModelClasses_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2644 (class 0 OID 0)
-- Dependencies: 155
-- Name: hardwareModelClasses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "hardwareModelClasses_id_seq" OWNED BY "hardwareModelClasses".id;


--
-- TOC entry 158 (class 1259 OID 23848)
-- Dependencies: 2289 2290 6
-- Name: hardwareModels; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "hardwareModels" (
    "lastUpdatedBy" character varying(64) DEFAULT 'Deployment'::character varying NOT NULL,
    "lastUpdateDate" timestamp without time zone DEFAULT now() NOT NULL,
    id integer NOT NULL,
    "hardwareModelName" character varying(64) NOT NULL,
    "hardwareModelClassId" integer NOT NULL,
    "manufacturerId" integer NOT NULL
);


--
-- TOC entry 157 (class 1259 OID 23846)
-- Dependencies: 158 6
-- Name: hardwareModels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "hardwareModels_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2645 (class 0 OID 0)
-- Dependencies: 157
-- Name: hardwareModels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "hardwareModels_id_seq" OWNED BY "hardwareModels".id;


--
-- TOC entry 164 (class 1259 OID 23900)
-- Dependencies: 6
-- Name: hardwareStatuses; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "hardwareStatuses" (
    id integer NOT NULL,
    "statusName" character varying(16) NOT NULL
);


--
-- TOC entry 163 (class 1259 OID 23898)
-- Dependencies: 6 164
-- Name: hardwareStatuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "hardwareStatuses_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2646 (class 0 OID 0)
-- Dependencies: 163
-- Name: hardwareStatuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "hardwareStatuses_id_seq" OWNED BY "hardwareStatuses".id;


--
-- TOC entry 166 (class 1259 OID 23910)
-- Dependencies: 2297 2298 6
-- Name: hardwares; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE hardwares (
    "lastUpdatedBy" character varying(64) DEFAULT 'Deployment'::character varying NOT NULL,
    "lastUpdateDate" timestamp without time zone DEFAULT now() NOT NULL,
    id integer NOT NULL,
    "hardwareModelId" integer NOT NULL,
    "hardwareSerial" text NOT NULL,
    "hardwareStatusId" integer NOT NULL
);


--
-- TOC entry 165 (class 1259 OID 23908)
-- Dependencies: 166 6
-- Name: hardwares_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE hardwares_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2647 (class 0 OID 0)
-- Dependencies: 165
-- Name: hardwares_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE hardwares_id_seq OWNED BY hardwares.id;


--
-- TOC entry 197 (class 1259 OID 24227)
-- Dependencies: 2361 2362 6
-- Name: headNodes; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "headNodes" (
    "lastUpdatedBy" character varying(64) DEFAULT 'Deployment'::character varying NOT NULL,
    "lastUpdateDate" timestamp without time zone DEFAULT now() NOT NULL,
    id integer NOT NULL,
    "systemId" integer NOT NULL,
    "castorInstanceId" integer NOT NULL,
    "primaryFunctionTypeId" integer NOT NULL,
    "secondaryFunctionTypeId" integer NOT NULL
);


--
-- TOC entry 196 (class 1259 OID 24225)
-- Dependencies: 197 6
-- Name: headNodes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "headNodes_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2648 (class 0 OID 0)
-- Dependencies: 196
-- Name: headNodes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "headNodes_id_seq" OWNED BY "headNodes".id;


--
-- TOC entry 218 (class 1259 OID 24409)
-- Dependencies: 2390 2391 6
-- Name: hostAddresses; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "hostAddresses" (
    "lastUpdatedBy" character varying(64) DEFAULT 'Deployment'::character varying NOT NULL,
    "lastUpdateDate" timestamp without time zone DEFAULT now() NOT NULL,
    id integer NOT NULL,
    "ipAddress" inet NOT NULL,
    "networkInterfaceId" integer,
    "networkSubnetId" integer NOT NULL
);


--
-- TOC entry 217 (class 1259 OID 24407)
-- Dependencies: 218 6
-- Name: hostAddresses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "hostAddresses_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2649 (class 0 OID 0)
-- Dependencies: 217
-- Name: hostAddresses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "hostAddresses_id_seq" OWNED BY "hostAddresses".id;


--
-- TOC entry 207 (class 1259 OID 24314)
-- Dependencies: 2372 2373 6
-- Name: hostnames; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE hostnames (
    "lastUpdatedBy" character varying(64) DEFAULT 'Deployment'::character varying NOT NULL,
    "lastUpdateDate" timestamp without time zone DEFAULT now() NOT NULL,
    id integer NOT NULL,
    name character varying(64) NOT NULL,
    "domainId" integer NOT NULL,
    "hostAddressId" integer NOT NULL
);


--
-- TOC entry 210 (class 1259 OID 24346)
-- Dependencies: 2378 2379 6
-- Name: hostnamesAliases; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "hostnamesAliases" (
    "lastUpdatedBy" character varying(64) DEFAULT 'Deployment'::character varying NOT NULL,
    "lastUpdateDate" timestamp without time zone DEFAULT now() NOT NULL,
    "hostnameId" integer NOT NULL,
    "aliasId" integer NOT NULL
);


--
-- TOC entry 206 (class 1259 OID 24312)
-- Dependencies: 6 207
-- Name: hostnames_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE hostnames_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2650 (class 0 OID 0)
-- Dependencies: 206
-- Name: hostnames_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE hostnames_id_seq OWNED BY hostnames.id;


--
-- TOC entry 169 (class 1259 OID 23967)
-- Dependencies: 6
-- Name: interventionActionClasses; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "interventionActionClasses" (
    id integer NOT NULL,
    "statusName" character varying(16) NOT NULL
);


--
-- TOC entry 168 (class 1259 OID 23965)
-- Dependencies: 6 169
-- Name: interventionActionClasses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "interventionActionClasses_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2651 (class 0 OID 0)
-- Dependencies: 168
-- Name: interventionActionClasses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "interventionActionClasses_id_seq" OWNED BY "interventionActionClasses".id;


--
-- TOC entry 171 (class 1259 OID 23977)
-- Dependencies: 2307 2308 6
-- Name: interventionActions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "interventionActions" (
    "lastUpdatedBy" character varying(64) DEFAULT 'Deployment'::character varying NOT NULL,
    "lastUpdateDate" timestamp without time zone DEFAULT now() NOT NULL,
    id integer NOT NULL,
    "interventionActionClassId" integer NOT NULL,
    "interventionActionTimestamp" timestamp without time zone NOT NULL,
    "interventionActionNote" character varying(1024) NOT NULL,
    "hardwareId" integer NOT NULL,
    "systemId" integer NOT NULL
);


--
-- TOC entry 170 (class 1259 OID 23975)
-- Dependencies: 6 171
-- Name: interventionActions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "interventionActions_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2652 (class 0 OID 0)
-- Dependencies: 170
-- Name: interventionActions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "interventionActions_id_seq" OWNED BY "interventionActions".id;


--
-- TOC entry 251 (class 1259 OID 24701)
-- Dependencies: 2393 6
-- Name: ipSurvey; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "ipSurvey" (
    "ipAddress" inet NOT NULL,
    "lastSeen" timestamp without time zone DEFAULT now() NOT NULL
);


--
-- TOC entry 150 (class 1259 OID 23803)
-- Dependencies: 2279 2280 6
-- Name: lifestages; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE lifestages (
    "lastUpdatedBy" character varying(64) DEFAULT 'Deployment'::character varying NOT NULL,
    "lastUpdateDate" timestamp without time zone DEFAULT now() NOT NULL,
    id integer NOT NULL,
    "lifestageName" character varying(32) NOT NULL
);


--
-- TOC entry 149 (class 1259 OID 23801)
-- Dependencies: 150 6
-- Name: lifestages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE lifestages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2653 (class 0 OID 0)
-- Dependencies: 149
-- Name: lifestages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE lifestages_id_seq OWNED BY lifestages.id;


--
-- TOC entry 154 (class 1259 OID 23826)
-- Dependencies: 2285 2286 6
-- Name: manufacturers; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE manufacturers (
    "lastUpdatedBy" character varying(64) DEFAULT 'Deployment'::character varying NOT NULL,
    "lastUpdateDate" timestamp without time zone DEFAULT now() NOT NULL,
    id integer NOT NULL,
    "manufacturerName" character varying(255) NOT NULL
);


--
-- TOC entry 153 (class 1259 OID 23824)
-- Dependencies: 154 6
-- Name: manufacturers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE manufacturers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2654 (class 0 OID 0)
-- Dependencies: 153
-- Name: manufacturers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE manufacturers_id_seq OWNED BY manufacturers.id;


--
-- TOC entry 212 (class 1259 OID 24365)
-- Dependencies: 2381 6
-- Name: networkInterfaceTypes; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "networkInterfaceTypes" (
    id integer NOT NULL,
    speed integer NOT NULL,
    description character varying(255) NOT NULL,
    CONSTRAINT "networkInterfaceTypes_speed_check" CHECK ((speed > 0))
);


--
-- TOC entry 211 (class 1259 OID 24363)
-- Dependencies: 212 6
-- Name: networkInterfaceTypes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "networkInterfaceTypes_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2655 (class 0 OID 0)
-- Dependencies: 211
-- Name: networkInterfaceTypes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "networkInterfaceTypes_id_seq" OWNED BY "networkInterfaceTypes".id;


--
-- TOC entry 214 (class 1259 OID 24374)
-- Dependencies: 2382 2384 2385 2386 6
-- Name: networkInterfaces; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "networkInterfaces" (
    "lastUpdatedBy" character varying(64) DEFAULT "current_user"() NOT NULL,
    "lastUpdateDate" timestamp without time zone DEFAULT now() NOT NULL,
    id integer NOT NULL,
    "macAddress" macaddr NOT NULL,
    name character varying(255) NOT NULL,
    "systemId" integer NOT NULL,
    "networkInterfaceTypeId" integer DEFAULT 2 NOT NULL,
    "isBootInterface" boolean DEFAULT false NOT NULL
);


--
-- TOC entry 213 (class 1259 OID 24372)
-- Dependencies: 214 6
-- Name: networkInterfaces_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "networkInterfaces_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2656 (class 0 OID 0)
-- Dependencies: 213
-- Name: networkInterfaces_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "networkInterfaces_id_seq" OWNED BY "networkInterfaces".id;


--
-- TOC entry 216 (class 1259 OID 24394)
-- Dependencies: 2387 2389 6
-- Name: networkSubnets; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "networkSubnets" (
    "lastUpdatedBy" character varying(64) DEFAULT "current_user"() NOT NULL,
    "lastUpdateDate" timestamp without time zone DEFAULT now() NOT NULL,
    id integer NOT NULL,
    "ipAddress" cidr NOT NULL,
    gateway inet NOT NULL,
    name character varying(255) NOT NULL
);


--
-- TOC entry 215 (class 1259 OID 24392)
-- Dependencies: 6 216
-- Name: networkSubnets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "networkSubnets_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2657 (class 0 OID 0)
-- Dependencies: 215
-- Name: networkSubnets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "networkSubnets_id_seq" OWNED BY "networkSubnets".id;


--
-- TOC entry 145 (class 1259 OID 23761)
-- Dependencies: 2266 2267 2269 2270 2271 6
-- Name: rackModels; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "rackModels" (
    "lastUpdatedBy" character varying(64) DEFAULT 'Deployment'::character varying NOT NULL,
    "lastUpdateDate" timestamp without time zone DEFAULT now() NOT NULL,
    id integer NOT NULL,
    "rackModelName" character varying(32) NOT NULL,
    "rackModelWidth" smallint NOT NULL,
    "rackModelDepth" smallint NOT NULL,
    "rackModelUnits" smallint NOT NULL,
    CONSTRAINT "rackModels_rackModelDepth_check" CHECK (("rackModelDepth" > 0)),
    CONSTRAINT "rackModels_rackModelUnits_check" CHECK (("rackModelUnits" >= 0)),
    CONSTRAINT "rackModels_rackModelWidth_check" CHECK (("rackModelWidth" > 0))
);


--
-- TOC entry 144 (class 1259 OID 23759)
-- Dependencies: 6 145
-- Name: rackModels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "rackModels_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2658 (class 0 OID 0)
-- Dependencies: 144
-- Name: rackModels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "rackModels_id_seq" OWNED BY "rackModels".id;


--
-- TOC entry 146 (class 1259 OID 23772)
-- Dependencies: 2272 2273 2274 2275 6
-- Name: racks; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE racks (
    "lastUpdatedBy" character varying(64) DEFAULT 'Deployment'::character varying NOT NULL,
    "lastUpdateDate" timestamp without time zone DEFAULT now() NOT NULL,
    id integer NOT NULL,
    "roomId" integer NOT NULL,
    "rackRow" numeric(6,3) NOT NULL,
    "rackCol" numeric(6,3) NOT NULL,
    description character varying(250) NOT NULL,
    "rackModelId" integer NOT NULL,
    serial character varying(64),
    CONSTRAINT "racks_rackCol_check" CHECK (("rackCol" >= (0)::numeric)),
    CONSTRAINT "racks_rackRow_check" CHECK (("rackRow" >= (0)::numeric))
);


--
-- TOC entry 143 (class 1259 OID 23749)
-- Dependencies: 2261 2262 2264 2265 6
-- Name: rooms; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE rooms (
    "lastUpdatedBy" character varying(64) DEFAULT 'Deployment'::character varying NOT NULL,
    "lastUpdateDate" timestamp without time zone DEFAULT now() NOT NULL,
    id integer NOT NULL,
    "roomName" character varying(25) NOT NULL,
    "roomBuilding" character varying(25) NOT NULL,
    "roomRows" smallint NOT NULL,
    "roomCols" smallint NOT NULL,
    CONSTRAINT "rooms_roomCols_check" CHECK (("roomCols" >= 0)),
    CONSTRAINT "rooms_roomRows_check" CHECK (("roomRows" >= 0))
);


--
-- TOC entry 142 (class 1259 OID 23747)
-- Dependencies: 6 143
-- Name: rooms_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE rooms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2659 (class 0 OID 0)
-- Dependencies: 142
-- Name: rooms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE rooms_id_seq OWNED BY rooms.id;


--
-- TOC entry 177 (class 1259 OID 24038)
-- Dependencies: 2320 2321 6
-- Name: serviceTypes; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "serviceTypes" (
    "lastUpdatedBy" character varying(64) DEFAULT 'Deployment'::character varying NOT NULL,
    "lastUpdateDate" timestamp without time zone DEFAULT now() NOT NULL,
    id integer NOT NULL,
    "serviceTypeName" character varying(16) NOT NULL
);


--
-- TOC entry 176 (class 1259 OID 24036)
-- Dependencies: 6 177
-- Name: serviceTypes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "serviceTypes_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2660 (class 0 OID 0)
-- Dependencies: 176
-- Name: serviceTypes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "serviceTypes_id_seq" OWNED BY "serviceTypes".id;


--
-- TOC entry 179 (class 1259 OID 24050)
-- Dependencies: 2323 2324 6
-- Name: statuses; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE statuses (
    "lastUpdatedBy" character varying(64) DEFAULT 'Deployment'::character varying NOT NULL,
    "lastUpdateDate" timestamp without time zone DEFAULT now() NOT NULL,
    id integer NOT NULL,
    "statusName" character varying(16) NOT NULL
);


--
-- TOC entry 178 (class 1259 OID 24048)
-- Dependencies: 6 179
-- Name: statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2661 (class 0 OID 0)
-- Dependencies: 178
-- Name: statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE statuses_id_seq OWNED BY statuses.id;


--
-- TOC entry 203 (class 1259 OID 24291)
-- Dependencies: 6
-- Name: storageSystemArchives; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "storageSystemArchives" (
    id integer NOT NULL,
    "archiveReason" character varying(16),
    "lastUpdatedBy" character varying(64),
    "lastUpdateDate" timestamp without time zone,
    "storageSystemId" integer,
    "machineName" character varying(255),
    "currentStatus" character varying(16),
    "normalStatus" character varying(16),
    "currentTeam" character varying(16),
    "serviceType" character varying(16),
    "virtualOrganisation" character varying(16),
    "diskPool" character varying(32),
    "sizeTb" numeric(5,2),
    "numberFilesystems" smallint,
    "isPuppetManaged" boolean,
    "isQuattorManaged" boolean,
    "isYaimManaged" boolean,
    "miscComments" text
);


--
-- TOC entry 202 (class 1259 OID 24289)
-- Dependencies: 203 6
-- Name: storageSystemArchives_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "storageSystemArchives_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2662 (class 0 OID 0)
-- Dependencies: 202
-- Name: storageSystemArchives_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "storageSystemArchives_id_seq" OWNED BY "storageSystemArchives".id;


--
-- TOC entry 187 (class 1259 OID 24108)
-- Dependencies: 2337 2338 2339 2341 2342 2343 2344 2345 2346 2347 2348 2349 2350 2351 2352 6
-- Name: storageSystems; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "storageSystems" (
    "lastUpdatedBy" character varying(64) DEFAULT "current_user"() NOT NULL,
    "lastUpdateDate" timestamp without time zone DEFAULT now() NOT NULL,
    id integer NOT NULL,
    "systemId" integer NOT NULL,
    "currentStatusId" integer DEFAULT 9 NOT NULL,
    "normalStatusId" integer DEFAULT 9 NOT NULL,
    "currentTeamId" integer DEFAULT 1 NOT NULL,
    "serviceTypeId" integer DEFAULT 1 NOT NULL,
    "virtualOrganisationId" integer DEFAULT 11 NOT NULL,
    "diskPoolId" integer DEFAULT 15 NOT NULL,
    "sizeTb" numeric(5,2) NOT NULL,
    "numberFilesystems" smallint DEFAULT 3 NOT NULL,
    "isPuppetManaged" boolean DEFAULT false NOT NULL,
    "isQuattorManaged" boolean DEFAULT false NOT NULL,
    "isYaimManaged" boolean DEFAULT false NOT NULL,
    "miscComments" text,
    "lastVerified" date DEFAULT '2009-01-01'::date NOT NULL,
    CONSTRAINT "storageSystems_numberFilesystems_check" CHECK (("numberFilesystems" > 0)),
    CONSTRAINT "storageSystems_sizeTb_check" CHECK (("sizeTb" > (0)::numeric))
);


--
-- TOC entry 186 (class 1259 OID 24106)
-- Dependencies: 187 6
-- Name: storageSystems_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "storageSystems_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2663 (class 0 OID 0)
-- Dependencies: 186
-- Name: storageSystems_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "storageSystems_id_seq" OWNED BY "storageSystems".id;


--
-- TOC entry 249 (class 1259 OID 24683)
-- Dependencies: 6
-- Name: systems_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE systems_id_seq
    START WITH 3037
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 167 (class 1259 OID 23931)
-- Dependencies: 2300 2301 2302 2303 2304 2305 6
-- Name: systems; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE systems (
    "lastUpdatedBy" character varying(64) DEFAULT "current_user"() NOT NULL,
    "lastUpdateDate" timestamp without time zone DEFAULT now() NOT NULL,
    id integer DEFAULT nextval('systems_id_seq'::regclass) NOT NULL,
    "vendorId" integer NOT NULL,
    "rackId" integer NOT NULL,
    "systemRackUnits" smallint NOT NULL,
    "systemRackPos" smallint NOT NULL,
    "categoryId" integer NOT NULL,
    "lifestageId" integer DEFAULT 8 NOT NULL,
    "manufacturerId" integer,
    "serviceTag" character varying,
    CONSTRAINT "systems_systemRackPos_check" CHECK (("systemRackPos" >= 0)),
    CONSTRAINT "systems_systemRackUnits_check" CHECK (("systemRackUnits" >= 0))
);


--
-- TOC entry 189 (class 1259 OID 24165)
-- Dependencies: 6
-- Name: tapeDriveTypes; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "tapeDriveTypes" (
    id integer NOT NULL,
    name character varying(64) NOT NULL
);


--
-- TOC entry 188 (class 1259 OID 24163)
-- Dependencies: 189 6
-- Name: tapeDriveTypes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "tapeDriveTypes_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2664 (class 0 OID 0)
-- Dependencies: 188
-- Name: tapeDriveTypes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "tapeDriveTypes_id_seq" OWNED BY "tapeDriveTypes".id;


--
-- TOC entry 191 (class 1259 OID 24175)
-- Dependencies: 2354 2355 6
-- Name: tapeDrives; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "tapeDrives" (
    "lastUpdatedBy" character varying(64) DEFAULT 'Deployment'::character varying NOT NULL,
    "lastUpdateDate" timestamp without time zone DEFAULT now() NOT NULL,
    id integer NOT NULL,
    "tapeDriveTypeId" integer NOT NULL
);


--
-- TOC entry 190 (class 1259 OID 24173)
-- Dependencies: 6 191
-- Name: tapeDrives_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "tapeDrives_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2665 (class 0 OID 0)
-- Dependencies: 190
-- Name: tapeDrives_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "tapeDrives_id_seq" OWNED BY "tapeDrives".id;


--
-- TOC entry 193 (class 1259 OID 24190)
-- Dependencies: 2357 2358 6
-- Name: tapeServers; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "tapeServers" (
    "lastUpdatedBy" character varying(64) DEFAULT 'Deployment'::character varying NOT NULL,
    "lastUpdateDate" timestamp without time zone DEFAULT now() NOT NULL,
    id integer NOT NULL,
    "systemId" integer NOT NULL,
    "virtualOrganisationId" integer,
    "typeDriveId" integer NOT NULL
);


--
-- TOC entry 192 (class 1259 OID 24188)
-- Dependencies: 193 6
-- Name: tapeServers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "tapeServers_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2666 (class 0 OID 0)
-- Dependencies: 192
-- Name: tapeServers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "tapeServers_id_seq" OWNED BY "tapeServers".id;


--
-- TOC entry 181 (class 1259 OID 24060)
-- Dependencies: 2326 2327 6
-- Name: teams; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE teams (
    "lastUpdatedBy" character varying(64) DEFAULT 'Deployment'::character varying NOT NULL,
    "lastUpdateDate" timestamp without time zone DEFAULT now() NOT NULL,
    id integer NOT NULL,
    "teamName" character varying(16) NOT NULL
);


--
-- TOC entry 180 (class 1259 OID 24058)
-- Dependencies: 6 181
-- Name: teams_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE teams_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2667 (class 0 OID 0)
-- Dependencies: 180
-- Name: teams_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE teams_id_seq OWNED BY teams.id;


--
-- TOC entry 257 (class 1259 OID 24800)
-- Dependencies: 2253 6
-- Name: vSystemMultiNames; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "vSystemMultiNames" AS
    SELECT ni."systemId", ni."isBootInterface", ni.id AS "networkInterfaceId", ha.id AS "hostAddressId", h.id AS "hostanameId", d.id AS "domainId", h.name, d."domainName", row_number() OVER (PARTITION BY ni."systemId" ORDER BY ni."systemId", ni."isBootInterface" DESC, ni.id, ha.id, h.id) AS "nameIndex" FROM "networkInterfaces" ni, "hostAddresses" ha, hostnames h, domains d WHERE (((ha."networkInterfaceId" = ni.id) AND (h."hostAddressId" = ha.id)) AND (h."domainId" = d.id));


--
-- TOC entry 2668 (class 0 OID 0)
-- Dependencies: 257
-- Name: VIEW "vSystemMultiNames"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW "vSystemMultiNames" IS 'Same as vSystemNames but exposes all names for systems with an index counter.';


--
-- TOC entry 152 (class 1259 OID 23813)
-- Dependencies: 2282 2283 6
-- Name: vendors; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE vendors (
    "lastUpdatedBy" character varying(64) DEFAULT 'Deployment'::character varying NOT NULL,
    "lastUpdateDate" timestamp without time zone DEFAULT now() NOT NULL,
    id integer NOT NULL,
    "vendorEmailAddress" character varying(255) NOT NULL,
    "vendorName" character varying(255) NOT NULL,
    "serviceTagURL" character varying
);


--
-- TOC entry 229 (class 1259 OID 24559)
-- Dependencies: 2227 6
-- Name: vBuildTemplate; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "vBuildTemplate" AS
    SELECT systems.id AS "systemId", ((("vSystemMultiNames".name)::text || '.'::text) || ("vSystemMultiNames"."domainName")::text) AS "systemHostname", rooms."roomBuilding", rooms."roomName", systems."systemRackPos", systems."rackId", racks."rackRow", racks."rackCol", categories."categoryName", vendors."vendorName", lifestages."lifestageName", systems."serviceTag" FROM systems, racks, rooms, categories, vendors, "vSystemMultiNames", lifestages WHERE ((((((systems."rackId" = racks.id) AND (racks."roomId" = rooms.id)) AND (systems."categoryId" = categories.id)) AND (systems."vendorId" = vendors.id)) AND (systems.id = "vSystemMultiNames"."systemId")) AND (systems."lifestageId" = lifestages.id));


--
-- TOC entry 219 (class 1259 OID 24511)
-- Dependencies: 2217 6
-- Name: vSystemNames; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "vSystemNames" AS
    WITH summary AS (SELECT ni."systemId", ni."isBootInterface", ni.id AS "networkInterfaceId", ha.id AS "hostAddressId", h.id AS "hostanameId", d.id AS "domainId", h.name, d."domainName", row_number() OVER (PARTITION BY ni."systemId" ORDER BY ni."systemId", ni."isBootInterface" DESC, ni.id, ha.id, h.id) AS rk FROM "networkInterfaces" ni, "hostAddresses" ha, hostnames h, domains d WHERE (((ha."networkInterfaceId" = ni.id) AND (h."hostAddressId" = ha.id)) AND (h."domainId" = d.id))) SELECT s."systemId", s."isBootInterface", s."networkInterfaceId", s."hostAddressId", s."hostanameId", s."domainId", s.name, s."domainName", s.rk FROM summary s WHERE (s.rk = 1);


--
-- TOC entry 185 (class 1259 OID 24091)
-- Dependencies: 2334 2335 6
-- Name: virtualOrganisations; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "virtualOrganisations" (
    "lastUpdatedBy" character varying(64) DEFAULT 'Deployment'::character varying NOT NULL,
    "lastUpdateDate" timestamp without time zone DEFAULT now() NOT NULL,
    id integer NOT NULL,
    "virtualOrganisationName" character varying(16) NOT NULL,
    "castorInstanceId" integer NOT NULL
);


--
-- TOC entry 220 (class 1259 OID 24516)
-- Dependencies: 2218 6
-- Name: vCastor; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "vCastor" AS
    SELECT vsn.name AS "machineName", stat1."statusName" AS "currentStatus", stat2."statusName" AS "normalStatus", teams."teamName" AS "currentTeam", st."serviceTypeName" AS "serviceType", ci."castorInstanceName" AS "castorInstance", vo."virtualOrganisationName" AS "virtualOrganisation", dp."diskPoolName" AS "diskPool", sys."sizeTb", sys."numberFilesystems" AS "numberFileSystems", hg."categoryName" AS "hardwareGroup", sys."isPuppetManaged" AS "puppetManaged", sys."isQuattorManaged" AS "quattorManaged", sys."miscComments", sys."lastVerified", ((('d'::text || (dp."diskNum")::text) || 't'::text) || (dp."tapeNum")::text) AS dxtx FROM "vSystemNames" vsn, systems s, "storageSystems" sys, statuses stat1, statuses stat2, teams teams, "serviceTypes" st, "virtualOrganisations" vo, "diskPools" dp, categories hg, "castorInstances" ci WHERE ((((((((((sys."currentStatusId" = stat1.id) AND (sys."normalStatusId" = stat2.id)) AND (sys."currentTeamId" = teams.id)) AND (sys."serviceTypeId" = st.id)) AND (sys."virtualOrganisationId" = vo.id)) AND (sys."diskPoolId" = dp.id)) AND (dp."castorInstanceId" = ci.id)) AND (sys."systemId" = s.id)) AND (s."categoryId" = hg.id)) AND (s.id = vsn."systemId"));


--
-- TOC entry 260 (class 1259 OID 24877)
-- Dependencies: 2256 6
-- Name: vAlastairsQuery; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "vAlastairsQuery" AS
    SELECT "vBuildTemplate"."systemHostname", "vBuildTemplate"."rackId", "vCastor"."castorInstance", "vCastor"."virtualOrganisation", "vCastor"."diskPool", "vCastor"."hardwareGroup" FROM ("vCastor" JOIN "vBuildTemplate" ON (("vBuildTemplate"."systemHostname" ~~ (("vCastor"."machineName")::text || '%'::text)))) WHERE (("vCastor"."hardwareGroup")::text = 'disk-2007-viglen-amd'::text) ORDER BY "vBuildTemplate"."systemHostname";


--
-- TOC entry 226 (class 1259 OID 24545)
-- Dependencies: 2224 6
-- Name: vAliases; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "vAliases" AS
    SELECT h.id AS "hostnameId", h.name AS host, dh."domainName" AS "hostDomain", a.id AS "aliasId", a.name AS alias, da."domainName" AS "aliasDomian" FROM hostnames h, aliases a, "hostnamesAliases" ha, domains dh, domains da WHERE ((((h.id = ha."hostnameId") AND (a.id = ha."aliasId")) AND (h."domainId" = dh.id)) AND (a."domainId" = da.id)) ORDER BY h.name;


--
-- TOC entry 221 (class 1259 OID 24521)
-- Dependencies: 2219 6
-- Name: vCastor2; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "vCastor2" AS
    SELECT vsn.name AS "machineName", vsn."domainName" AS domain, sys."currentStatusId" AS "currentStatus", sys."normalStatusId" AS "normalStatus", sys."currentTeamId" AS "currentTeam", sys."serviceTypeId" AS "serviceType", sys."virtualOrganisationId" AS "virtualOrganisation", sys."diskPoolId" AS "diskPool", sys."sizeTb", sys."numberFilesystems" AS "numberFileSystems", c."categoryName" AS "hardwareGroup", sys."isPuppetManaged" AS "puppetManaged", sys."isQuattorManaged" AS "quattorManaged", sys."isYaimManaged" AS "yaimManaged", sys."miscComments", sys."lastVerified", sys.id AS "storageSystemId" FROM systems s, "storageSystems" sys, categories c, "vSystemNames" vsn WHERE (((sys."systemId" = s.id) AND (s."categoryId" = c.id)) AND (vsn."systemId" = s.id)) ORDER BY ("substring"((vsn.name)::text, '[0-9]+'::text))::integer;


--
-- TOC entry 222 (class 1259 OID 24526)
-- Dependencies: 2220 6
-- Name: vCastor3; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "vCastor3" AS
    SELECT vsn.name AS "machineName", stat1."statusName" AS "currentStatus", stat2."statusName" AS "normalStatus", teams."teamName" AS "currentTeam", st."serviceTypeName" AS "serviceType", ci."castorInstanceName" AS "castorInstance", vo."virtualOrganisationName" AS "virtualOrganisation", dp."diskPoolName" AS "diskPool", sys."sizeTb", sys."numberFilesystems" AS "numberFileSystems", hg."categoryName" AS "hardwareGroup", sys."isPuppetManaged" AS "puppetManaged", sys."isQuattorManaged" AS "quattorManaged", sys."miscComments", sys."lastVerified", ((('d'::text || (dp."diskNum")::text) || 't'::text) || (dp."tapeNum")::text) AS dxtx FROM "vSystemNames" vsn, systems s, "storageSystems" sys, statuses stat1, statuses stat2, teams teams, "serviceTypes" st, "virtualOrganisations" vo, "diskPools" dp, categories hg, "castorInstances" ci WHERE ((((((((((sys."currentStatusId" = stat1.id) AND (sys."normalStatusId" = stat2.id)) AND (sys."currentTeamId" = teams.id)) AND (sys."serviceTypeId" = st.id)) AND (sys."virtualOrganisationId" = vo.id)) AND (sys."diskPoolId" = dp.id)) AND (dp."castorInstanceId" = ci.id)) AND (sys."systemId" = s.id)) AND (s."categoryId" = hg.id)) AND (s.id = vsn."systemId")) ORDER BY ("substring"((vsn.name)::text, '[0-9]+'::text))::integer;


--
-- TOC entry 223 (class 1259 OID 24531)
-- Dependencies: 2221 6
-- Name: vCastor4; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "vCastor4" AS
    SELECT vsn.name AS "machineName", vsn."domainId" AS domain, sys."lastUpdatedBy", sys."lastUpdateDate", sys."currentStatusId" AS "currentStatus", sys."normalStatusId" AS "normalStatus", sys."currentTeamId" AS "currentTeam", sys."serviceTypeId" AS "serviceType", sys."virtualOrganisationId" AS "virtualOrganisation", sys."diskPoolId" AS "diskPool", sys."sizeTb", sys."numberFilesystems" AS "numberFileSystems", s."categoryId" AS "hardwareGroup", sys."isPuppetManaged" AS "puppetManaged", sys."isQuattorManaged" AS "quattorManaged", sys."miscComments", sys."lastVerified", sys.id AS "storageSystemId" FROM systems s, "storageSystems" sys, "vSystemNames" vsn WHERE ((sys."systemId" = s.id) AND (vsn."systemId" = s.id)) ORDER BY ("substring"((vsn.name)::text, '[0-9]+'::text))::integer;


--
-- TOC entry 224 (class 1259 OID 24536)
-- Dependencies: 2222 6
-- Name: vCastor5; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "vCastor5" AS
    SELECT vsn.name AS "machineName", sys.id AS "storageSystemId", sys."systemId", stat1."statusName" AS "currentStatus", stat2."statusName" AS "normalStatus", teams."teamName" AS "currentTeam", st."serviceTypeName" AS "serviceType", ci."castorInstanceName" AS "castorInstance", vo."virtualOrganisationName" AS "virtualOrganisation", dp."diskPoolName" AS "diskPool", sys."sizeTb", sys."numberFilesystems" AS "numberFileSystems", hg."categoryName" AS "hardwareGroup", sys."isPuppetManaged" AS "puppetManaged", sys."isQuattorManaged" AS "quattorManaged", sys."miscComments", sys."lastVerified", ((('d'::text || (dp."diskNum")::text) || 't'::text) || (dp."tapeNum")::text) AS dxtx FROM "vSystemNames" vsn, systems s, "storageSystems" sys, statuses stat1, statuses stat2, teams teams, "serviceTypes" st, "virtualOrganisations" vo, "diskPools" dp, categories hg, "castorInstances" ci WHERE ((((((((((sys."currentStatusId" = stat1.id) AND (sys."normalStatusId" = stat2.id)) AND (sys."currentTeamId" = teams.id)) AND (sys."serviceTypeId" = st.id)) AND (sys."virtualOrganisationId" = vo.id)) AND (sys."diskPoolId" = dp.id)) AND (dp."castorInstanceId" = ci.id)) AND (sys."systemId" = s.id)) AND (s."categoryId" = hg.id)) AND (s.id = vsn."systemId"));


--
-- TOC entry 245 (class 1259 OID 24625)
-- Dependencies: 2243 6
-- Name: vCastorPoolstypeCount2; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "vCastorPoolstypeCount2" AS
    SELECT "vCastor"."diskPool" AS disk, "vCastor"."hardwareGroup" AS gr, count("vCastor"."hardwareGroup") AS num, "vCastor"."sizeTb" AS size FROM "vCastor" GROUP BY "vCastor"."hardwareGroup", "vCastor"."diskPool", "vCastor"."sizeTb" ORDER BY "vCastor"."diskPool";


--
-- TOC entry 246 (class 1259 OID 24629)
-- Dependencies: 2244 6
-- Name: vCastorPoolsType2; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "vCastorPoolsType2" AS
    SELECT "vCastorPoolstypeCount2".disk, "vCastorPoolstypeCount2".gr, sum((("vCastorPoolstypeCount2".num)::numeric * "vCastorPoolstypeCount2".size)) AS max_size FROM "vCastorPoolstypeCount2" GROUP BY "vCastorPoolstypeCount2".disk, "vCastorPoolstypeCount2".gr;


--
-- TOC entry 230 (class 1259 OID 24564)
-- Dependencies: 2228 6
-- Name: vCastorPoolsTypeCount; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "vCastorPoolsTypeCount" AS
    SELECT "vCastor"."diskPool", "vCastor"."hardwareGroup", count("vCastor"."hardwareGroup") AS num, "vCastor"."sizeTb" FROM "vCastor" GROUP BY "vCastor"."hardwareGroup", "vCastor"."diskPool", "vCastor"."sizeTb" ORDER BY "vCastor"."diskPool";


--
-- TOC entry 247 (class 1259 OID 24658)
-- Dependencies: 2245 6
-- Name: vCategoryVendor; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "vCategoryVendor" AS
    SELECT systems.id, categories."categoryName", vendors."vendorName" FROM ((systems JOIN vendors ON ((systems."vendorId" = vendors.id))) JOIN categories ON ((systems."categoryId" = categories.id)));


--
-- TOC entry 259 (class 1259 OID 24827)
-- Dependencies: 2255 6
-- Name: vDnsInternal; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "vDnsInternal" AS
    SELECT hostnames.name, "hostAddresses"."ipAddress" FROM (hostnames JOIN "hostAddresses" ON ((hostnames."hostAddressId" = "hostAddresses".id))) WHERE (hostnames."domainId" = 14) ORDER BY hostnames.name;


--
-- TOC entry 261 (class 1259 OID 24898)
-- Dependencies: 2257 6
-- Name: vHardtrackCategorySystems; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "vHardtrackCategorySystems" AS
    SELECT "vSystemNames"."systemId", ((("vSystemNames".name)::text || '.'::text) || ("vSystemNames"."domainName")::text) AS "systemHostname", "vCategoryVendor"."categoryName", "vCategoryVendor"."vendorName" FROM ("vSystemNames" JOIN "vCategoryVendor" ON (("vCategoryVendor".id = "vSystemNames"."systemId"))) ORDER BY "vCategoryVendor"."categoryName", "vSystemNames"."systemId";


--
-- TOC entry 255 (class 1259 OID 24785)
-- Dependencies: 2251 6
-- Name: vHardtrackRackUnits; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "vHardtrackRackUnits" AS
    SELECT systems."rackId", systems."systemRackPos", systems.id, ((("vSystemNames".name)::text || '.'::text) || ("vSystemNames"."domainName")::text) AS "systemHostname", systems."systemRackUnits", lifestages."lifestageName" FROM (((((systems LEFT JOIN "vSystemNames" ON ((systems.id = "vSystemNames"."systemId"))) JOIN racks ON ((systems."rackId" = racks.id))) JOIN rooms ON ((racks."roomId" = rooms.id))) JOIN lifestages ON ((systems."lifestageId" = lifestages.id))) JOIN categories ON ((systems."categoryId" = categories.id)));


--
-- TOC entry 250 (class 1259 OID 24691)
-- Dependencies: 2247 6
-- Name: vHardtrackRacks; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "vHardtrackRacks" AS
    SELECT systems.id AS "systemId", ((("vSystemNames".name)::text || '.'::text) || ("vSystemNames"."domainName")::text) AS "systemHostname", systems."systemRackPos", systems."systemRackUnits", systems."rackId", racks."rackRow", racks."rackCol", categories."categoryName" FROM ((((systems LEFT JOIN "vSystemNames" ON ((systems.id = "vSystemNames"."systemId"))) JOIN racks ON ((systems."rackId" = racks.id))) JOIN rooms ON ((racks."roomId" = rooms.id))) JOIN categories ON ((systems."categoryId" = categories.id)));


--
-- TOC entry 231 (class 1259 OID 24568)
-- Dependencies: 2229 6
-- Name: vNagiosCastorSystems; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "vNagiosCastorSystems" AS
    SELECT vc4."lastUpdatedBy", vc4."lastUpdateDate", vc4."machineName", vc4.domain, vc4."currentStatus", vc4."normalStatus", vc4."currentTeam", vc4."serviceType", vc4."virtualOrganisation", vc4."diskPool", vc4."sizeTb", vc4."numberFileSystems" AS "numberFilesystems", vc4."hardwareGroup", vc4."puppetManaged", vc4."miscComments", vc4."lastVerified", dp."castorInstanceId" FROM "vCastor4" vc4, "diskPools" dp WHERE (((vc4."currentTeam" = 2) AND (vc4."diskPool" = dp.id)) AND ((vc4."serviceType" = 2) OR (vc4."serviceType" = 3)));


--
-- TOC entry 232 (class 1259 OID 24573)
-- Dependencies: 2230 6
-- Name: vNagiosCastor219; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "vNagiosCastor219" AS
    SELECT "vNagiosCastorSystems"."machineName" FROM "vNagiosCastorSystems" WHERE (((((("vNagiosCastorSystems"."castorInstanceId" = 1) OR ("vNagiosCastorSystems"."castorInstanceId" = 2)) OR ("vNagiosCastorSystems"."castorInstanceId" = 3)) OR ("vNagiosCastorSystems"."castorInstanceId" = 4)) OR ("vNagiosCastorSystems"."castorInstanceId" = 7)) AND (("vNagiosCastorSystems"."normalStatus" <> 7) AND ("vNagiosCastorSystems"."normalStatus" <> 10)));


--
-- TOC entry 233 (class 1259 OID 24577)
-- Dependencies: 2231 6
-- Name: vNagiosCastorCallout; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "vNagiosCastorCallout" AS
    SELECT "vNagiosCastorSystems"."machineName", "vNagiosCastorSystems"."numberFilesystems" FROM "vNagiosCastorSystems" WHERE ((((("vNagiosCastorSystems"."virtualOrganisation" <> 3) AND ("vNagiosCastorSystems"."normalStatus" = 5)) AND ("vNagiosCastorSystems"."diskPool" <> 41)) AND ("vNagiosCastorSystems"."diskPool" <> 44)) AND (((("vNagiosCastorSystems"."castorInstanceId" = 1) OR ("vNagiosCastorSystems"."castorInstanceId" = 2)) OR ("vNagiosCastorSystems"."castorInstanceId" = 3)) OR ("vNagiosCastorSystems"."castorInstanceId" = 4)));


--
-- TOC entry 234 (class 1259 OID 24581)
-- Dependencies: 2232 6
-- Name: vNagiosCastorInstance; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "vNagiosCastorInstance" AS
    SELECT "vNagiosCastorSystems"."machineName", "vNagiosCastorSystems"."castorInstanceId" FROM ("vNagiosCastorSystems" JOIN "diskPools" ON (("diskPools".id = "vNagiosCastorSystems"."diskPool"))) WHERE (((("vNagiosCastorSystems"."normalStatus" <> 2) AND ("vNagiosCastorSystems"."normalStatus" <> 7)) AND ("vNagiosCastorSystems"."normalStatus" <> 9)) AND ("vNagiosCastorSystems"."normalStatus" <> 10));


--
-- TOC entry 235 (class 1259 OID 24585)
-- Dependencies: 2233 6
-- Name: vNagiosCastorInstanceAtlas; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "vNagiosCastorInstanceAtlas" AS
    SELECT "vNagiosCastorInstance"."machineName" FROM "vNagiosCastorInstance" WHERE ("vNagiosCastorInstance"."castorInstanceId" = 1) ORDER BY "vNagiosCastorInstance"."machineName";


--
-- TOC entry 236 (class 1259 OID 24589)
-- Dependencies: 2234 6
-- Name: vNagiosCastorInstanceCMS; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "vNagiosCastorInstanceCMS" AS
    SELECT "vNagiosCastorInstance"."machineName" FROM "vNagiosCastorInstance" WHERE ("vNagiosCastorInstance"."castorInstanceId" = 2) ORDER BY "vNagiosCastorInstance"."machineName";


--
-- TOC entry 237 (class 1259 OID 24593)
-- Dependencies: 2235 6
-- Name: vNagiosCastorInstanceCert; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "vNagiosCastorInstanceCert" AS
    SELECT "vNagiosCastorInstance"."machineName" FROM "vNagiosCastorInstance" WHERE ("vNagiosCastorInstance"."castorInstanceId" = 5) ORDER BY "vNagiosCastorInstance"."machineName";


--
-- TOC entry 238 (class 1259 OID 24597)
-- Dependencies: 2236 6
-- Name: vNagiosCastorInstanceFac; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "vNagiosCastorInstanceFac" AS
    SELECT "vNagiosCastorInstance"."machineName" FROM "vNagiosCastorInstance" WHERE ("vNagiosCastorInstance"."castorInstanceId" = 7) ORDER BY "vNagiosCastorInstance"."machineName";


--
-- TOC entry 239 (class 1259 OID 24601)
-- Dependencies: 2237 6
-- Name: vNagiosCastorInstanceGen; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "vNagiosCastorInstanceGen" AS
    SELECT "vNagiosCastorInstance"."machineName" FROM "vNagiosCastorInstance" WHERE ("vNagiosCastorInstance"."castorInstanceId" = 3) ORDER BY "vNagiosCastorInstance"."machineName";


--
-- TOC entry 240 (class 1259 OID 24605)
-- Dependencies: 2238 6
-- Name: vNagiosCastorInstanceLHCb; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "vNagiosCastorInstanceLHCb" AS
    SELECT "vNagiosCastorInstance"."machineName" FROM "vNagiosCastorInstance" WHERE ("vNagiosCastorInstance"."castorInstanceId" = 4) ORDER BY "vNagiosCastorInstance"."machineName";


--
-- TOC entry 241 (class 1259 OID 24609)
-- Dependencies: 2239 6
-- Name: vNagiosCastorInstancePreprod; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "vNagiosCastorInstancePreprod" AS
    SELECT "vNagiosCastorInstance"."machineName" FROM "vNagiosCastorInstance" WHERE ("vNagiosCastorInstance"."castorInstanceId" = 6) ORDER BY "vNagiosCastorInstance"."machineName";


--
-- TOC entry 253 (class 1259 OID 24768)
-- Dependencies: 2249 6
-- Name: vNagiosCastorInstanceRepack; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "vNagiosCastorInstanceRepack" AS
    SELECT "vNagiosCastorSystems"."lastUpdatedBy", "vNagiosCastorSystems"."lastUpdateDate", "vNagiosCastorSystems"."machineName", "vNagiosCastorSystems".domain, "vNagiosCastorSystems"."currentStatus", "vNagiosCastorSystems"."normalStatus", "vNagiosCastorSystems"."currentTeam", "vNagiosCastorSystems"."serviceType", "vNagiosCastorSystems"."virtualOrganisation", "vNagiosCastorSystems"."diskPool", "vNagiosCastorSystems"."sizeTb", "vNagiosCastorSystems"."numberFilesystems", "vNagiosCastorSystems"."hardwareGroup", "vNagiosCastorSystems"."puppetManaged", "vNagiosCastorSystems"."miscComments", "vNagiosCastorSystems"."lastVerified", "vNagiosCastorSystems"."castorInstanceId" FROM "vNagiosCastorSystems" WHERE ("vNagiosCastorSystems"."castorInstanceId" = 9);


--
-- TOC entry 242 (class 1259 OID 24613)
-- Dependencies: 2240 6
-- Name: vNagiosCastorInverseNotMonitored; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "vNagiosCastorInverseNotMonitored" AS
    SELECT "vNagiosCastorSystems"."machineName" FROM "vNagiosCastorSystems" WHERE ((((("vNagiosCastorSystems"."normalStatus" <> 2) AND ("vNagiosCastorSystems"."normalStatus" <> 7)) AND ("vNagiosCastorSystems"."normalStatus" <> 9)) AND ("vNagiosCastorSystems"."normalStatus" <> 10)) AND ("vNagiosCastorSystems"."normalStatus" <> 12));


--
-- TOC entry 243 (class 1259 OID 24617)
-- Dependencies: 2241 6
-- Name: vNagiosCastorNonCallout; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "vNagiosCastorNonCallout" AS
    SELECT "vNagiosCastorSystems"."machineName" FROM "vNagiosCastorSystems" WHERE (((((("vNagiosCastorSystems"."castorInstanceId" = 1) OR ("vNagiosCastorSystems"."castorInstanceId" = 2)) OR ("vNagiosCastorSystems"."castorInstanceId" = 3)) OR ("vNagiosCastorSystems"."castorInstanceId" = 4)) OR ("vNagiosCastorSystems"."castorInstanceId" = 7)) AND ((((((((((("vNagiosCastorSystems"."normalStatus" <> 5) AND ("vNagiosCastorSystems"."normalStatus" <> 9)) AND ("vNagiosCastorSystems"."normalStatus" <> 7)) AND ("vNagiosCastorSystems"."normalStatus" <> 10)) AND ("vNagiosCastorSystems"."normalStatus" <> 12)) OR ("vNagiosCastorSystems"."diskPool" = 41)) OR ("vNagiosCastorSystems"."diskPool" = 44)) OR ("vNagiosCastorSystems"."diskPool" = 1)) OR ("vNagiosCastorSystems"."diskPool" = 2)) OR ("vNagiosCastorSystems"."diskPool" = 3)) OR ("vNagiosCastorSystems"."diskPool" = 4)));


--
-- TOC entry 244 (class 1259 OID 24621)
-- Dependencies: 2242 6
-- Name: vNagiosCastorNonCalloutMonitored; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "vNagiosCastorNonCalloutMonitored" AS
    SELECT "vNagiosCastorSystems"."machineName" FROM "vNagiosCastorSystems" WHERE (((("vNagiosCastorSystems"."normalStatus" = 6) OR ("vNagiosCastorSystems"."normalStatus" = 2)) OR ("vNagiosCastorSystems"."normalStatus" = 3)) OR ("vNagiosCastorSystems"."diskPool" = 41));


--
-- TOC entry 227 (class 1259 OID 24549)
-- Dependencies: 2225 6
-- Name: vNetwork; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "vNetwork" AS
    SELECT "hostAddresses"."ipAddress", "networkInterfaces"."systemId", (((hostnames.name)::text || '.'::text) || (domains."domainName")::text) AS fqdn FROM ((("hostAddresses" LEFT JOIN hostnames ON ((hostnames."hostAddressId" = "hostAddresses".id))) LEFT JOIN domains ON ((hostnames."domainId" = domains.id))) LEFT JOIN "networkInterfaces" ON (("hostAddresses"."networkInterfaceId" = "networkInterfaces".id))) ORDER BY "networkInterfaces"."systemId";


--
-- TOC entry 228 (class 1259 OID 24554)
-- Dependencies: 2226 6
-- Name: vNetwork2; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "vNetwork2" AS
    SELECT "networkInterfaces"."systemId", "networkInterfaces"."macAddress", "hostAddresses"."ipAddress", (((hostnames.name)::text || '.'::text) || (domains."domainName")::text) AS fqdn FROM ((("hostAddresses" LEFT JOIN hostnames ON ((hostnames."hostAddressId" = "hostAddresses".id))) LEFT JOIN domains ON ((hostnames."domainId" = domains.id))) LEFT JOIN "networkInterfaces" ON (("hostAddresses"."networkInterfaceId" = "networkInterfaces".id))) ORDER BY "networkInterfaces"."systemId";


--
-- TOC entry 258 (class 1259 OID 24805)
-- Dependencies: 2254 6
-- Name: vNetwork3; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "vNetwork3" AS
    SELECT "networkInterfaces"."systemId", "networkInterfaces"."macAddress", "hostAddresses"."ipAddress", (((hostnames.name)::text || '.'::text) || (domains."domainName")::text) AS fqdn, ((("vAliases".alias)::text || '.'::text) || ("vAliases"."aliasDomian")::text) AS alias FROM (((("hostAddresses" LEFT JOIN hostnames ON ((hostnames."hostAddressId" = "hostAddresses".id))) LEFT JOIN domains ON ((hostnames."domainId" = domains.id))) LEFT JOIN "networkInterfaces" ON (("hostAddresses"."networkInterfaceId" = "networkInterfaces".id))) LEFT JOIN "vAliases" ON (("vAliases"."hostnameId" = hostnames.id))) ORDER BY "networkInterfaces"."systemId";


--
-- TOC entry 2669 (class 0 OID 0)
-- Dependencies: 258
-- Name: VIEW "vNetwork3"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW "vNetwork3" IS 'Same as vNetwork2 but with aliases';


--
-- TOC entry 263 (class 1259 OID 41781)
-- Dependencies: 2259 6
-- Name: vNetworkHogs; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "vNetworkHogs" AS
    SELECT "vNetwork"."ipAddress", "vNetwork".fqdn FROM ("vNetwork" LEFT JOIN "ipSurvey" ON (("vNetwork"."ipAddress" = "ipSurvey"."ipAddress"))) WHERE (((((((("ipSurvey"."lastSeen" IS NULL) OR ("ipSurvey"."lastSeen" < (now() - '28 days'::interval))) AND ("vNetwork".fqdn !~~ 'cloud%.gridpp.rl.ac.uk'::text)) AND ("vNetwork".fqdn !~~ 'scdcloud%.fds.rl.ac.uk'::text)) AND ("vNetwork".fqdn !~~ 'pool%.contrail.rl.ac.uk'::text)) AND ("vNetwork".fqdn !~~ 'vds%.gridpp.rl.ac.uk'::text)) AND ("vNetwork".fqdn !~~ 'cpre%.gridpp.rl.ac.uk'::text)) AND ("vNetwork".fqdn !~~ '%.internal'::text));


--
-- TOC entry 254 (class 1259 OID 24780)
-- Dependencies: 2250 6
-- Name: vNetworkInterfaces; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "vNetworkInterfaces" AS
    SELECT "networkInterfaces"."systemId", "networkInterfaces".name, "networkInterfaces"."macAddress", "networkInterfaceTypes".description, "networkInterfaces"."isBootInterface", array_to_string(ARRAY(SELECT "hostAddresses"."ipAddress" FROM "hostAddresses" WHERE ("hostAddresses"."networkInterfaceId" = "networkInterfaces".id)), ' '::text) AS "ipAddresses" FROM ("networkInterfaces" JOIN "networkInterfaceTypes" ON (("networkInterfaceTypes".id = "networkInterfaces"."networkInterfaceTypeId")));


--
-- TOC entry 264 (class 1259 OID 41785)
-- Dependencies: 2260 6
-- Name: vNetworkSquatters; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "vNetworkSquatters" AS
    SELECT "ipSurvey"."ipAddress" FROM ("ipSurvey" LEFT JOIN "vNetwork" ON (("vNetwork"."ipAddress" = "ipSurvey"."ipAddress"))) WHERE (("vNetwork"."ipAddress" IS NULL) AND ("ipSurvey"."lastSeen" > (now() - '28 days'::interval)));


--
-- TOC entry 256 (class 1259 OID 24794)
-- Dependencies: 2252 6
-- Name: vNetworkStubs; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "vNetworkStubs" AS
    SELECT "vNetwork"."ipAddress", "vNetwork".fqdn FROM "vNetwork" WHERE ("vNetwork"."systemId" IS NULL);


--
-- TOC entry 2670 (class 0 OID 0)
-- Dependencies: 256
-- Name: VIEW "vNetworkStubs"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW "vNetworkStubs" IS 'Show all network records which are stub entries (have no associated physical system).';


--
-- TOC entry 262 (class 1259 OID 41223)
-- Dependencies: 2258 6
-- Name: vPDUs; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "vPDUs" AS
    SELECT systems."rackId", systems.id AS "pduId", "hostAddresses"."ipAddress" FROM ((systems LEFT JOIN "networkInterfaces" ON (("networkInterfaces"."systemId" = systems.id))) LEFT JOIN "hostAddresses" ON (("hostAddresses"."networkInterfaceId" = "networkInterfaces".id))) WHERE (systems."categoryId" = ANY (ARRAY[23, 83, 84, 86]));


--
-- TOC entry 252 (class 1259 OID 24755)
-- Dependencies: 2248 6
-- Name: vRacks; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "vRacks" AS
    SELECT racks.id, racks."rackRow", racks."rackCol", racks.description, "rackModels"."rackModelWidth", "rackModels"."rackModelDepth", racks."roomId", "rackModels"."rackModelName", racks.serial FROM (racks JOIN "rackModels" ON ((racks."rackModelId" = "rackModels".id)));


--
-- TOC entry 225 (class 1259 OID 24541)
-- Dependencies: 2223 6
-- Name: vStatus; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "vStatus" AS
    SELECT systems.id AS "systemId", systems."systemRackPos", systems."rackId", rooms."roomName", categories."categoryName", vendors."vendorName", systems."serviceTag", vendors."serviceTagURL", lifestages."lifestageName" FROM systems, racks, rooms, categories, vendors, lifestages WHERE (((((systems."rackId" = racks.id) AND (racks."roomId" = rooms.id)) AND (systems."categoryId" = categories.id)) AND (systems."vendorId" = vendors.id)) AND (systems."lifestageId" = lifestages.id));


--
-- TOC entry 248 (class 1259 OID 24674)
-- Dependencies: 2246 6
-- Name: vStorageSystemsTest; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "vStorageSystemsTest" AS
    SELECT ss.id, ss."systemId", c."categoryName", statc."statusName" AS "currentStatus", statn."statusName" AS "normalStatus" FROM "storageSystems" ss, systems s, categories c, statuses statn, statuses statc WHERE (((((ss."currentStatusId" = statc.id) AND (ss."normalStatusId" = statn.id)) AND (ss."systemId" = s.id)) AND (s."categoryId" = c.id)) AND (ss."currentStatusId" = 9)) ORDER BY c."categoryName";


--
-- TOC entry 151 (class 1259 OID 23811)
-- Dependencies: 6 152
-- Name: vendors_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE vendors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2671 (class 0 OID 0)
-- Dependencies: 151
-- Name: vendors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE vendors_id_seq OWNED BY vendors.id;


--
-- TOC entry 184 (class 1259 OID 24089)
-- Dependencies: 185 6
-- Name: virtualOrganisations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "virtualOrganisations_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2672 (class 0 OID 0)
-- Dependencies: 184
-- Name: virtualOrganisations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "virtualOrganisations_id_seq" OWNED BY "virtualOrganisations".id;


--
-- TOC entry 2329 (class 2604 OID 24075)
-- Dependencies: 183 182 183
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY admins ALTER COLUMN id SET DEFAULT nextval('admins_id_seq'::regclass);


--
-- TOC entry 2377 (class 2604 OID 24336)
-- Dependencies: 208 209 209
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY aliases ALTER COLUMN id SET DEFAULT nextval('aliases_id_seq'::regclass);


--
-- TOC entry 2312 (class 2604 OID 24010)
-- Dependencies: 172 173 173
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "castorInstances" ALTER COLUMN id SET DEFAULT nextval('"castorInstances_id_seq"'::regclass);


--
-- TOC entry 2278 (class 2604 OID 23798)
-- Dependencies: 148 147 148
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY categories ALTER COLUMN id SET DEFAULT nextval('categories_id_seq'::regclass);


--
-- TOC entry 2367 (class 2604 OID 24274)
-- Dependencies: 200 201 201
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "databaseServers" ALTER COLUMN id SET DEFAULT nextval('"databaseServers_id_seq"'::regclass);


--
-- TOC entry 2364 (class 2604 OID 24262)
-- Dependencies: 199 198 199
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "databaseTypes" ALTER COLUMN id SET DEFAULT nextval('"databaseTypes_id_seq"'::regclass);


--
-- TOC entry 2315 (class 2604 OID 24022)
-- Dependencies: 175 174 175
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "diskPools" ALTER COLUMN id SET DEFAULT nextval('"diskPools_id_seq"'::regclass);


--
-- TOC entry 2371 (class 2604 OID 24307)
-- Dependencies: 204 205 205
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY domains ALTER COLUMN id SET DEFAULT nextval('domains_id_seq'::regclass);


--
-- TOC entry 2360 (class 2604 OID 24220)
-- Dependencies: 195 194 195
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "functionTypes" ALTER COLUMN id SET DEFAULT nextval('"functionTypes_id_seq"'::regclass);


--
-- TOC entry 2292 (class 2604 OID 23871)
-- Dependencies: 160 159 160
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "hardwareModelAttributeTypes" ALTER COLUMN id SET DEFAULT nextval('"hardwareModelAttributeTypes_id_seq"'::regclass);


--
-- TOC entry 2295 (class 2604 OID 23883)
-- Dependencies: 161 162 162
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "hardwareModelAttributes" ALTER COLUMN id SET DEFAULT nextval('"hardwareModelAttributes_id_seq"'::regclass);


--
-- TOC entry 2288 (class 2604 OID 23841)
-- Dependencies: 155 156 156
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "hardwareModelClasses" ALTER COLUMN id SET DEFAULT nextval('"hardwareModelClasses_id_seq"'::regclass);


--
-- TOC entry 2291 (class 2604 OID 23853)
-- Dependencies: 158 157 158
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "hardwareModels" ALTER COLUMN id SET DEFAULT nextval('"hardwareModels_id_seq"'::regclass);


--
-- TOC entry 2296 (class 2604 OID 23903)
-- Dependencies: 164 163 164
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "hardwareStatuses" ALTER COLUMN id SET DEFAULT nextval('"hardwareStatuses_id_seq"'::regclass);


--
-- TOC entry 2299 (class 2604 OID 23915)
-- Dependencies: 166 165 166
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY hardwares ALTER COLUMN id SET DEFAULT nextval('hardwares_id_seq'::regclass);


--
-- TOC entry 2363 (class 2604 OID 24232)
-- Dependencies: 197 196 197
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "headNodes" ALTER COLUMN id SET DEFAULT nextval('"headNodes_id_seq"'::regclass);


--
-- TOC entry 2392 (class 2604 OID 24414)
-- Dependencies: 218 217 218
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "hostAddresses" ALTER COLUMN id SET DEFAULT nextval('"hostAddresses_id_seq"'::regclass);


--
-- TOC entry 2374 (class 2604 OID 24319)
-- Dependencies: 206 207 207
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY hostnames ALTER COLUMN id SET DEFAULT nextval('hostnames_id_seq'::regclass);


--
-- TOC entry 2306 (class 2604 OID 23970)
-- Dependencies: 168 169 169
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "interventionActionClasses" ALTER COLUMN id SET DEFAULT nextval('"interventionActionClasses_id_seq"'::regclass);


--
-- TOC entry 2309 (class 2604 OID 23982)
-- Dependencies: 171 170 171
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "interventionActions" ALTER COLUMN id SET DEFAULT nextval('"interventionActions_id_seq"'::regclass);


--
-- TOC entry 2281 (class 2604 OID 23808)
-- Dependencies: 150 149 150
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY lifestages ALTER COLUMN id SET DEFAULT nextval('lifestages_id_seq'::regclass);


--
-- TOC entry 2287 (class 2604 OID 23831)
-- Dependencies: 154 153 154
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY manufacturers ALTER COLUMN id SET DEFAULT nextval('manufacturers_id_seq'::regclass);


--
-- TOC entry 2380 (class 2604 OID 24368)
-- Dependencies: 211 212 212
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "networkInterfaceTypes" ALTER COLUMN id SET DEFAULT nextval('"networkInterfaceTypes_id_seq"'::regclass);


--
-- TOC entry 2383 (class 2604 OID 24379)
-- Dependencies: 213 214 214
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "networkInterfaces" ALTER COLUMN id SET DEFAULT nextval('"networkInterfaces_id_seq"'::regclass);


--
-- TOC entry 2388 (class 2604 OID 24399)
-- Dependencies: 216 215 216
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "networkSubnets" ALTER COLUMN id SET DEFAULT nextval('"networkSubnets_id_seq"'::regclass);


--
-- TOC entry 2268 (class 2604 OID 23766)
-- Dependencies: 145 144 145
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "rackModels" ALTER COLUMN id SET DEFAULT nextval('"rackModels_id_seq"'::regclass);


--
-- TOC entry 2263 (class 2604 OID 23754)
-- Dependencies: 143 142 143
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY rooms ALTER COLUMN id SET DEFAULT nextval('rooms_id_seq'::regclass);


--
-- TOC entry 2322 (class 2604 OID 24043)
-- Dependencies: 177 176 177
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "serviceTypes" ALTER COLUMN id SET DEFAULT nextval('"serviceTypes_id_seq"'::regclass);


--
-- TOC entry 2325 (class 2604 OID 24055)
-- Dependencies: 179 178 179
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY statuses ALTER COLUMN id SET DEFAULT nextval('statuses_id_seq'::regclass);


--
-- TOC entry 2368 (class 2604 OID 24294)
-- Dependencies: 202 203 203
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "storageSystemArchives" ALTER COLUMN id SET DEFAULT nextval('"storageSystemArchives_id_seq"'::regclass);


--
-- TOC entry 2340 (class 2604 OID 24113)
-- Dependencies: 187 186 187
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "storageSystems" ALTER COLUMN id SET DEFAULT nextval('"storageSystems_id_seq"'::regclass);


--
-- TOC entry 2353 (class 2604 OID 24168)
-- Dependencies: 188 189 189
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "tapeDriveTypes" ALTER COLUMN id SET DEFAULT nextval('"tapeDriveTypes_id_seq"'::regclass);


--
-- TOC entry 2356 (class 2604 OID 24180)
-- Dependencies: 191 190 191
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "tapeDrives" ALTER COLUMN id SET DEFAULT nextval('"tapeDrives_id_seq"'::regclass);


--
-- TOC entry 2359 (class 2604 OID 24195)
-- Dependencies: 193 192 193
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "tapeServers" ALTER COLUMN id SET DEFAULT nextval('"tapeServers_id_seq"'::regclass);


--
-- TOC entry 2328 (class 2604 OID 24065)
-- Dependencies: 181 180 181
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY teams ALTER COLUMN id SET DEFAULT nextval('teams_id_seq'::regclass);


--
-- TOC entry 2284 (class 2604 OID 23818)
-- Dependencies: 151 152 152
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY vendors ALTER COLUMN id SET DEFAULT nextval('vendors_id_seq'::regclass);


--
-- TOC entry 2336 (class 2604 OID 24096)
-- Dependencies: 184 185 185
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "virtualOrganisations" ALTER COLUMN id SET DEFAULT nextval('"virtualOrganisations_id_seq"'::regclass);


--
-- TOC entry 2457 (class 2606 OID 24083)
-- Dependencies: 183 183 183 183 183 183 2625
-- Name: admins_commonName_countryName_organisation_organisationalUn_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY admins
    ADD CONSTRAINT "admins_commonName_countryName_organisation_organisationalUn_key" UNIQUE ("commonName", "countryName", organisation, "organisationalUnit", location);


--
-- TOC entry 2459 (class 2606 OID 24081)
-- Dependencies: 183 183 2625
-- Name: admins_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY admins
    ADD CONSTRAINT admins_pkey PRIMARY KEY (id);


--
-- TOC entry 2506 (class 2606 OID 24340)
-- Dependencies: 209 209 209 2625
-- Name: aliases_name_domainId_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY aliases
    ADD CONSTRAINT "aliases_name_domainId_key" UNIQUE (name, "domainId");


--
-- TOC entry 2508 (class 2606 OID 24338)
-- Dependencies: 209 209 2625
-- Name: aliases_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY aliases
    ADD CONSTRAINT aliases_pkey PRIMARY KEY (id);


--
-- TOC entry 2439 (class 2606 OID 24014)
-- Dependencies: 173 173 2625
-- Name: castorInstances_castorInstanceName_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "castorInstances"
    ADD CONSTRAINT "castorInstances_castorInstanceName_key" UNIQUE ("castorInstanceName");


--
-- TOC entry 2441 (class 2606 OID 24012)
-- Dependencies: 173 173 2625
-- Name: castorInstances_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "castorInstances"
    ADD CONSTRAINT "castorInstances_pkey" PRIMARY KEY (id);


--
-- TOC entry 2401 (class 2606 OID 23800)
-- Dependencies: 148 148 2625
-- Name: categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- TOC entry 2491 (class 2606 OID 24276)
-- Dependencies: 201 201 2625
-- Name: databaseServers_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "databaseServers"
    ADD CONSTRAINT "databaseServers_pkey" PRIMARY KEY (id);


--
-- TOC entry 2493 (class 2606 OID 24278)
-- Dependencies: 201 201 2625
-- Name: databaseServers_systemId_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "databaseServers"
    ADD CONSTRAINT "databaseServers_systemId_key" UNIQUE ("systemId");


--
-- TOC entry 2487 (class 2606 OID 24266)
-- Dependencies: 199 199 2625
-- Name: databaseTypes_name_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "databaseTypes"
    ADD CONSTRAINT "databaseTypes_name_key" UNIQUE (name);


--
-- TOC entry 2489 (class 2606 OID 24264)
-- Dependencies: 199 199 2625
-- Name: databaseTypes_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "databaseTypes"
    ADD CONSTRAINT "databaseTypes_pkey" PRIMARY KEY (id);


--
-- TOC entry 2443 (class 2606 OID 24030)
-- Dependencies: 175 175 2625
-- Name: diskPools_diskPoolName_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "diskPools"
    ADD CONSTRAINT "diskPools_diskPoolName_key" UNIQUE ("diskPoolName");


--
-- TOC entry 2445 (class 2606 OID 24028)
-- Dependencies: 175 175 2625
-- Name: diskPools_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "diskPools"
    ADD CONSTRAINT "diskPools_pkey" PRIMARY KEY (id);


--
-- TOC entry 2497 (class 2606 OID 24311)
-- Dependencies: 205 205 2625
-- Name: domains_domainName_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY domains
    ADD CONSTRAINT "domains_domainName_key" UNIQUE ("domainName");


--
-- TOC entry 2499 (class 2606 OID 24309)
-- Dependencies: 205 205 2625
-- Name: domains_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY domains
    ADD CONSTRAINT domains_pkey PRIMARY KEY (id);


--
-- TOC entry 2479 (class 2606 OID 24224)
-- Dependencies: 195 195 2625
-- Name: functionTypes_name_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "functionTypes"
    ADD CONSTRAINT "functionTypes_name_key" UNIQUE (name);


--
-- TOC entry 2481 (class 2606 OID 24222)
-- Dependencies: 195 195 2625
-- Name: functionTypes_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "functionTypes"
    ADD CONSTRAINT "functionTypes_pkey" PRIMARY KEY (id);


--
-- TOC entry 2417 (class 2606 OID 23873)
-- Dependencies: 160 160 2625
-- Name: hardwareModelAttributeTypes_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "hardwareModelAttributeTypes"
    ADD CONSTRAINT "hardwareModelAttributeTypes_pkey" PRIMARY KEY (id);


--
-- TOC entry 2419 (class 2606 OID 23875)
-- Dependencies: 160 160 2625
-- Name: hardwareModelAttributeTypes_typeName_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "hardwareModelAttributeTypes"
    ADD CONSTRAINT "hardwareModelAttributeTypes_typeName_key" UNIQUE ("typeName");


--
-- TOC entry 2421 (class 2606 OID 23887)
-- Dependencies: 162 162 162 2625
-- Name: hardwareModelAttributes_hardwareModelId_hardwareModelAttrib_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "hardwareModelAttributes"
    ADD CONSTRAINT "hardwareModelAttributes_hardwareModelId_hardwareModelAttrib_key" UNIQUE ("hardwareModelId", "hardwareModelAttributeTypeId");


--
-- TOC entry 2423 (class 2606 OID 23885)
-- Dependencies: 162 162 2625
-- Name: hardwareModelAttributes_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "hardwareModelAttributes"
    ADD CONSTRAINT "hardwareModelAttributes_pkey" PRIMARY KEY (id);


--
-- TOC entry 2411 (class 2606 OID 23845)
-- Dependencies: 156 156 2625
-- Name: hardwareModelClasses_className_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "hardwareModelClasses"
    ADD CONSTRAINT "hardwareModelClasses_className_key" UNIQUE ("className");


--
-- TOC entry 2413 (class 2606 OID 23843)
-- Dependencies: 156 156 2625
-- Name: hardwareModelClasses_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "hardwareModelClasses"
    ADD CONSTRAINT "hardwareModelClasses_pkey" PRIMARY KEY (id);


--
-- TOC entry 2415 (class 2606 OID 23855)
-- Dependencies: 158 158 2625
-- Name: hardwareModels_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "hardwareModels"
    ADD CONSTRAINT "hardwareModels_pkey" PRIMARY KEY (id);


--
-- TOC entry 2425 (class 2606 OID 23905)
-- Dependencies: 164 164 2625
-- Name: hardwareStatuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "hardwareStatuses"
    ADD CONSTRAINT "hardwareStatuses_pkey" PRIMARY KEY (id);


--
-- TOC entry 2427 (class 2606 OID 23907)
-- Dependencies: 164 164 2625
-- Name: hardwareStatuses_statusName_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "hardwareStatuses"
    ADD CONSTRAINT "hardwareStatuses_statusName_key" UNIQUE ("statusName");


--
-- TOC entry 2429 (class 2606 OID 23920)
-- Dependencies: 166 166 2625
-- Name: hardwares_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY hardwares
    ADD CONSTRAINT hardwares_pkey PRIMARY KEY (id);


--
-- TOC entry 2483 (class 2606 OID 24234)
-- Dependencies: 197 197 2625
-- Name: headNodes_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "headNodes"
    ADD CONSTRAINT "headNodes_pkey" PRIMARY KEY (id);


--
-- TOC entry 2485 (class 2606 OID 24236)
-- Dependencies: 197 197 2625
-- Name: headNodes_systemId_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "headNodes"
    ADD CONSTRAINT "headNodes_systemId_key" UNIQUE ("systemId");


--
-- TOC entry 2525 (class 2606 OID 24510)
-- Dependencies: 218 218 2625
-- Name: hostAddresses_ipAddress_unique; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "hostAddresses"
    ADD CONSTRAINT "hostAddresses_ipAddress_unique" UNIQUE ("ipAddress");


--
-- TOC entry 2527 (class 2606 OID 24419)
-- Dependencies: 218 218 2625
-- Name: hostAddresses_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "hostAddresses"
    ADD CONSTRAINT "hostAddresses_pkey" PRIMARY KEY (id);


--
-- TOC entry 2511 (class 2606 OID 24352)
-- Dependencies: 210 210 210 2625
-- Name: hostnamesAliases_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "hostnamesAliases"
    ADD CONSTRAINT "hostnamesAliases_pkey" PRIMARY KEY ("hostnameId", "aliasId");


--
-- TOC entry 2502 (class 2606 OID 24323)
-- Dependencies: 207 207 207 2625
-- Name: hostnames_name_domainId_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY hostnames
    ADD CONSTRAINT "hostnames_name_domainId_key" UNIQUE (name, "domainId");


--
-- TOC entry 2504 (class 2606 OID 24321)
-- Dependencies: 207 207 2625
-- Name: hostnames_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY hostnames
    ADD CONSTRAINT hostnames_pkey PRIMARY KEY (id);


--
-- TOC entry 2433 (class 2606 OID 23972)
-- Dependencies: 169 169 2625
-- Name: interventionActionClasses_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "interventionActionClasses"
    ADD CONSTRAINT "interventionActionClasses_pkey" PRIMARY KEY (id);


--
-- TOC entry 2435 (class 2606 OID 23974)
-- Dependencies: 169 169 2625
-- Name: interventionActionClasses_statusName_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "interventionActionClasses"
    ADD CONSTRAINT "interventionActionClasses_statusName_key" UNIQUE ("statusName");


--
-- TOC entry 2437 (class 2606 OID 23987)
-- Dependencies: 171 171 2625
-- Name: interventionActions_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "interventionActions"
    ADD CONSTRAINT "interventionActions_pkey" PRIMARY KEY (id);


--
-- TOC entry 2529 (class 2606 OID 24727)
-- Dependencies: 251 251 2625
-- Name: ipSurvey_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "ipSurvey"
    ADD CONSTRAINT "ipSurvey_pkey" PRIMARY KEY ("ipAddress");


--
-- TOC entry 2403 (class 2606 OID 23810)
-- Dependencies: 150 150 2625
-- Name: lifestages_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY lifestages
    ADD CONSTRAINT lifestages_pkey PRIMARY KEY (id);


--
-- TOC entry 2407 (class 2606 OID 23835)
-- Dependencies: 154 154 2625
-- Name: manufacturers_manufacturerName_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY manufacturers
    ADD CONSTRAINT "manufacturers_manufacturerName_key" UNIQUE ("manufacturerName");


--
-- TOC entry 2409 (class 2606 OID 23833)
-- Dependencies: 154 154 2625
-- Name: manufacturers_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY manufacturers
    ADD CONSTRAINT manufacturers_pkey PRIMARY KEY (id);


--
-- TOC entry 2513 (class 2606 OID 24371)
-- Dependencies: 212 212 2625
-- Name: networkInterfaceTypes_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "networkInterfaceTypes"
    ADD CONSTRAINT "networkInterfaceTypes_pkey" PRIMARY KEY (id);


--
-- TOC entry 2515 (class 2606 OID 24381)
-- Dependencies: 214 214 2625
-- Name: networkInterfaces_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "networkInterfaces"
    ADD CONSTRAINT "networkInterfaces_pkey" PRIMARY KEY (id);


--
-- TOC entry 2521 (class 2606 OID 24406)
-- Dependencies: 216 216 2625
-- Name: networkSubnets_ipAddress_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "networkSubnets"
    ADD CONSTRAINT "networkSubnets_ipAddress_key" UNIQUE ("ipAddress");


--
-- TOC entry 2523 (class 2606 OID 24404)
-- Dependencies: 216 216 2625
-- Name: networkSubnets_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "networkSubnets"
    ADD CONSTRAINT "networkSubnets_pkey" PRIMARY KEY (id);


--
-- TOC entry 2397 (class 2606 OID 23771)
-- Dependencies: 145 145 2625
-- Name: rackModels_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "rackModels"
    ADD CONSTRAINT "rackModels_pkey" PRIMARY KEY (id);


--
-- TOC entry 2399 (class 2606 OID 23780)
-- Dependencies: 146 146 2625
-- Name: racks_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY racks
    ADD CONSTRAINT racks_pkey PRIMARY KEY (id);


--
-- TOC entry 2395 (class 2606 OID 23758)
-- Dependencies: 143 143 2625
-- Name: rooms_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY rooms
    ADD CONSTRAINT rooms_pkey PRIMARY KEY (id);


--
-- TOC entry 2447 (class 2606 OID 24045)
-- Dependencies: 177 177 2625
-- Name: serviceTypes_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "serviceTypes"
    ADD CONSTRAINT "serviceTypes_pkey" PRIMARY KEY (id);


--
-- TOC entry 2449 (class 2606 OID 24047)
-- Dependencies: 177 177 2625
-- Name: serviceTypes_serviceTypeName_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "serviceTypes"
    ADD CONSTRAINT "serviceTypes_serviceTypeName_key" UNIQUE ("serviceTypeName");


--
-- TOC entry 2451 (class 2606 OID 24057)
-- Dependencies: 179 179 2625
-- Name: statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY statuses
    ADD CONSTRAINT statuses_pkey PRIMARY KEY (id);


--
-- TOC entry 2495 (class 2606 OID 24299)
-- Dependencies: 203 203 2625
-- Name: storageSystemArchives_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "storageSystemArchives"
    ADD CONSTRAINT "storageSystemArchives_pkey" PRIMARY KEY (id);


--
-- TOC entry 2465 (class 2606 OID 24125)
-- Dependencies: 187 187 2625
-- Name: storageSystems_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "storageSystems"
    ADD CONSTRAINT "storageSystems_pkey" PRIMARY KEY (id);


--
-- TOC entry 2467 (class 2606 OID 24127)
-- Dependencies: 187 187 2625
-- Name: storageSystems_systemId_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "storageSystems"
    ADD CONSTRAINT "storageSystems_systemId_key" UNIQUE ("systemId");


--
-- TOC entry 2431 (class 2606 OID 23939)
-- Dependencies: 167 167 2625
-- Name: systems_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY systems
    ADD CONSTRAINT systems_pkey PRIMARY KEY (id);


--
-- TOC entry 2469 (class 2606 OID 24172)
-- Dependencies: 189 189 2625
-- Name: tapeDriveTypes_name_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "tapeDriveTypes"
    ADD CONSTRAINT "tapeDriveTypes_name_key" UNIQUE (name);


--
-- TOC entry 2471 (class 2606 OID 24170)
-- Dependencies: 189 189 2625
-- Name: tapeDriveTypes_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "tapeDriveTypes"
    ADD CONSTRAINT "tapeDriveTypes_pkey" PRIMARY KEY (id);


--
-- TOC entry 2473 (class 2606 OID 24182)
-- Dependencies: 191 191 2625
-- Name: tapeDrives_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "tapeDrives"
    ADD CONSTRAINT "tapeDrives_pkey" PRIMARY KEY (id);


--
-- TOC entry 2475 (class 2606 OID 24197)
-- Dependencies: 193 193 2625
-- Name: tapeServers_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "tapeServers"
    ADD CONSTRAINT "tapeServers_pkey" PRIMARY KEY (id);


--
-- TOC entry 2477 (class 2606 OID 24199)
-- Dependencies: 193 193 2625
-- Name: tapeServers_systemId_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "tapeServers"
    ADD CONSTRAINT "tapeServers_systemId_key" UNIQUE ("systemId");


--
-- TOC entry 2453 (class 2606 OID 24067)
-- Dependencies: 181 181 2625
-- Name: teams_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY teams
    ADD CONSTRAINT teams_pkey PRIMARY KEY (id);


--
-- TOC entry 2455 (class 2606 OID 24069)
-- Dependencies: 181 181 2625
-- Name: teams_teamName_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY teams
    ADD CONSTRAINT "teams_teamName_key" UNIQUE ("teamName");


--
-- TOC entry 2517 (class 2606 OID 24748)
-- Dependencies: 214 214 2625
-- Name: unique_macAddress; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "networkInterfaces"
    ADD CONSTRAINT "unique_macAddress" UNIQUE ("macAddress");


--
-- TOC entry 2519 (class 2606 OID 24875)
-- Dependencies: 214 214 214 2625
-- Name: unique_name; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "networkInterfaces"
    ADD CONSTRAINT unique_name UNIQUE ("systemId", name);


--
-- TOC entry 2405 (class 2606 OID 23823)
-- Dependencies: 152 152 2625
-- Name: vendors_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY vendors
    ADD CONSTRAINT vendors_pkey PRIMARY KEY (id);


--
-- TOC entry 2461 (class 2606 OID 24098)
-- Dependencies: 185 185 2625
-- Name: virtualOrganisations_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "virtualOrganisations"
    ADD CONSTRAINT "virtualOrganisations_pkey" PRIMARY KEY (id);


--
-- TOC entry 2463 (class 2606 OID 24100)
-- Dependencies: 185 185 2625
-- Name: virtualOrganisations_virtualOrganisationName_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "virtualOrganisations"
    ADD CONSTRAINT "virtualOrganisations_virtualOrganisationName_key" UNIQUE ("virtualOrganisationName");


--
-- TOC entry 2509 (class 1259 OID 24654)
-- Dependencies: 210 2625
-- Name: fki_hostnamesAliases_aliasId_fkey; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX "fki_hostnamesAliases_aliasId_fkey" ON "hostnamesAliases" USING btree ("aliasId");


--
-- TOC entry 2500 (class 1259 OID 24508)
-- Dependencies: 207 2625
-- Name: fki_hostnames_hostAddressId_fkey; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX "fki_hostnames_hostAddressId_fkey" ON hostnames USING btree ("hostAddressId");


--
-- TOC entry 2601 (class 2620 OID 24442)
-- Dependencies: 289 187 2625
-- Name: addarchivesystemstabletrigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER addarchivesystemstabletrigger AFTER DELETE OR UPDATE ON "storageSystems" FOR EACH ROW EXECUTE PROCEDURE addarchivesystemstable();


--
-- TOC entry 2600 (class 2620 OID 24466)
-- Dependencies: 187 280 187 187 2625
-- Name: checkequalcastorinstanceidtrigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER checkequalcastorinstanceidtrigger BEFORE UPDATE OF "diskPoolId", "virtualOrganisationId" ON "storageSystems" FOR EACH ROW EXECUTE PROCEDURE checkequalcastorinstanceid();


--
-- TOC entry 2619 (class 2620 OID 24458)
-- Dependencies: 216 276 2625
-- Name: checkgatewaytrigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER checkgatewaytrigger BEFORE INSERT OR UPDATE ON "networkSubnets" FOR EACH ROW EXECUTE PROCEDURE checkgateway();


--
-- TOC entry 2622 (class 2620 OID 24454)
-- Dependencies: 218 282 218 2625
-- Name: checkhostaddresstrigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER checkhostaddresstrigger BEFORE INSERT OR UPDATE OF "ipAddress" ON "hostAddresses" FOR EACH ROW EXECUTE PROCEDURE checkhostaddress();


--
-- TOC entry 2620 (class 2620 OID 24461)
-- Dependencies: 216 283 216 2625
-- Name: checknewnetworkaddresstrigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER checknewnetworkaddresstrigger BEFORE UPDATE OF "ipAddress" ON "networkSubnets" FOR EACH ROW EXECUTE PROCEDURE checknewnetworkaddress();


--
-- TOC entry 2587 (class 2620 OID 24440)
-- Dependencies: 284 167 2625
-- Name: checkrackunitstrigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER checkrackunitstrigger BEFORE INSERT OR UPDATE ON systems FOR EACH ROW EXECUTE PROCEDURE checkrackunits();


--
-- TOC entry 2577 (class 2620 OID 24438)
-- Dependencies: 146 281 2625
-- Name: checkrowscolstrigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER checkrowscolstrigger BEFORE INSERT OR UPDATE ON racks FOR EACH ROW EXECUTE PROCEDURE checkrowscols();


--
-- TOC entry 2591 (class 2620 OID 24463)
-- Dependencies: 175 285 175 2625
-- Name: checkunchagedcastorinstanceiddiskpooltrigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER checkunchagedcastorinstanceiddiskpooltrigger BEFORE UPDATE OF "castorInstanceId" ON "diskPools" FOR EACH ROW EXECUTE PROCEDURE checkunchagedcastorinstanceid();


--
-- TOC entry 2596 (class 2620 OID 24464)
-- Dependencies: 185 185 285 2625
-- Name: checkunchagedcastorinstanceidvirtualorganisationtrigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER checkunchagedcastorinstanceidvirtualorganisationtrigger BEFORE UPDATE OF "castorInstanceId" ON "virtualOrganisations" FOR EACH ROW EXECUTE PROCEDURE checkunchagedcastorinstanceid();


--
-- TOC entry 2610 (class 2620 OID 24447)
-- Dependencies: 201 286 2625
-- Name: checkuniquesystemiddatabaseserverstrigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER checkuniquesystemiddatabaseserverstrigger BEFORE INSERT ON "databaseServers" FOR EACH ROW EXECUTE PROCEDURE checkuniquesystemid();


--
-- TOC entry 2611 (class 2620 OID 24452)
-- Dependencies: 201 287 201 2625
-- Name: checkuniquesystemiddatabaseserverstrigger2; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER checkuniquesystemiddatabaseserverstrigger2 BEFORE UPDATE OF "systemId" ON "databaseServers" FOR EACH ROW EXECUTE PROCEDURE checkuniquesystemid2();


--
-- TOC entry 2607 (class 2620 OID 24445)
-- Dependencies: 286 197 2625
-- Name: checkuniquesystemidheadnodestrigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER checkuniquesystemidheadnodestrigger BEFORE INSERT ON "headNodes" FOR EACH ROW EXECUTE PROCEDURE checkuniquesystemid();


--
-- TOC entry 2608 (class 2620 OID 24450)
-- Dependencies: 287 197 197 2625
-- Name: checkuniquesystemidheadnodestrigger2; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER checkuniquesystemidheadnodestrigger2 BEFORE UPDATE OF "systemId" ON "headNodes" FOR EACH ROW EXECUTE PROCEDURE checkuniquesystemid2();


--
-- TOC entry 2598 (class 2620 OID 24444)
-- Dependencies: 286 187 2625
-- Name: checkuniquesystemidstoragesystemtrigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER checkuniquesystemidstoragesystemtrigger BEFORE INSERT ON "storageSystems" FOR EACH ROW EXECUTE PROCEDURE checkuniquesystemid();


--
-- TOC entry 2599 (class 2620 OID 24449)
-- Dependencies: 187 187 287 2625
-- Name: checkuniquesystemidstoragesystemtrigger2; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER checkuniquesystemidstoragesystemtrigger2 BEFORE UPDATE OF "systemId" ON "storageSystems" FOR EACH ROW EXECUTE PROCEDURE checkuniquesystemid2();


--
-- TOC entry 2604 (class 2620 OID 24446)
-- Dependencies: 286 193 2625
-- Name: checkuniquesystemidtapeserverstrigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER checkuniquesystemidtapeserverstrigger BEFORE INSERT ON "tapeServers" FOR EACH ROW EXECUTE PROCEDURE checkuniquesystemid();


--
-- TOC entry 2605 (class 2620 OID 24451)
-- Dependencies: 193 193 287 2625
-- Name: checkuniquesystemidtapeserverstrigger2; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER checkuniquesystemidtapeserverstrigger2 BEFORE UPDATE OF "systemId" ON "tapeServers" FOR EACH ROW EXECUTE PROCEDURE checkuniquesystemid2();


--
-- TOC entry 2617 (class 2620 OID 24499)
-- Dependencies: 288 210 2625
-- Name: deletealiasestrigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER deletealiasestrigger AFTER DELETE ON "hostnamesAliases" FOR EACH ROW EXECUTE PROCEDURE deletealiases();


--
-- TOC entry 2615 (class 2620 OID 24480)
-- Dependencies: 277 209 2625
-- Name: settimestampaliasestrigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER settimestampaliasestrigger BEFORE INSERT OR UPDATE ON aliases FOR EACH ROW EXECUTE PROCEDURE settimestamp();


--
-- TOC entry 2590 (class 2620 OID 24468)
-- Dependencies: 277 173 2625
-- Name: settimestampcastorinstancestrigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER settimestampcastorinstancestrigger BEFORE INSERT OR UPDATE ON "castorInstances" FOR EACH ROW EXECUTE PROCEDURE settimestamp();


--
-- TOC entry 2579 (class 2620 OID 24493)
-- Dependencies: 277 148 2625
-- Name: settimestampcategoriestrigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER settimestampcategoriestrigger BEFORE INSERT OR UPDATE ON categories FOR EACH ROW EXECUTE PROCEDURE settimestamp();


--
-- TOC entry 2612 (class 2620 OID 24478)
-- Dependencies: 277 201 2625
-- Name: settimestampdatabaseserverstrigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER settimestampdatabaseserverstrigger BEFORE INSERT OR UPDATE ON "databaseServers" FOR EACH ROW EXECUTE PROCEDURE settimestamp();


--
-- TOC entry 2592 (class 2620 OID 24472)
-- Dependencies: 175 277 2625
-- Name: settimestampdiskpoolstrigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER settimestampdiskpoolstrigger BEFORE INSERT OR UPDATE ON "diskPools" FOR EACH ROW EXECUTE PROCEDURE settimestamp();


--
-- TOC entry 2613 (class 2620 OID 24479)
-- Dependencies: 277 205 2625
-- Name: settimestampdomainstrigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER settimestampdomainstrigger BEFORE INSERT OR UPDATE ON domains FOR EACH ROW EXECUTE PROCEDURE settimestamp();


--
-- TOC entry 2585 (class 2620 OID 24489)
-- Dependencies: 162 277 2625
-- Name: settimestamphardwaremodelattributestrigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER settimestamphardwaremodelattributestrigger BEFORE INSERT OR UPDATE ON "hardwareModelAttributes" FOR EACH ROW EXECUTE PROCEDURE settimestamp();


--
-- TOC entry 2584 (class 2620 OID 24490)
-- Dependencies: 158 277 2625
-- Name: settimestamphardwaremodelstrigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER settimestamphardwaremodelstrigger BEFORE INSERT OR UPDATE ON "hardwareModels" FOR EACH ROW EXECUTE PROCEDURE settimestamp();


--
-- TOC entry 2586 (class 2620 OID 24488)
-- Dependencies: 166 277 2625
-- Name: settimestamphardwarestrigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER settimestamphardwarestrigger BEFORE INSERT OR UPDATE ON hardwares FOR EACH ROW EXECUTE PROCEDURE settimestamp();


--
-- TOC entry 2609 (class 2620 OID 24477)
-- Dependencies: 197 277 2625
-- Name: settimestampheadnodestrigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER settimestampheadnodestrigger BEFORE INSERT OR UPDATE ON "headNodes" FOR EACH ROW EXECUTE PROCEDURE settimestamp();


--
-- TOC entry 2623 (class 2620 OID 24484)
-- Dependencies: 218 277 2625
-- Name: settimestamphostaddressestrigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER settimestamphostaddressestrigger BEFORE INSERT OR UPDATE ON "hostAddresses" FOR EACH ROW EXECUTE PROCEDURE settimestamp();


--
-- TOC entry 2616 (class 2620 OID 24481)
-- Dependencies: 277 210 2625
-- Name: settimestamphostnamesaliasestrigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER settimestamphostnamesaliasestrigger BEFORE INSERT OR UPDATE ON "hostnamesAliases" FOR EACH ROW EXECUTE PROCEDURE settimestamp();


--
-- TOC entry 2614 (class 2620 OID 24482)
-- Dependencies: 277 207 2625
-- Name: settimestamphostnamestrigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER settimestamphostnamestrigger BEFORE INSERT OR UPDATE ON hostnames FOR EACH ROW EXECUTE PROCEDURE settimestamp();


--
-- TOC entry 2589 (class 2620 OID 24487)
-- Dependencies: 171 277 2625
-- Name: settimestampinterventionactionstrigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER settimestampinterventionactionstrigger BEFORE INSERT OR UPDATE ON "interventionActions" FOR EACH ROW EXECUTE PROCEDURE settimestamp();


--
-- TOC entry 2580 (class 2620 OID 24494)
-- Dependencies: 150 277 2625
-- Name: settimestamplifestagestrigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER settimestamplifestagestrigger BEFORE INSERT OR UPDATE ON lifestages FOR EACH ROW EXECUTE PROCEDURE settimestamp();


--
-- TOC entry 2583 (class 2620 OID 24491)
-- Dependencies: 154 277 2625
-- Name: settimestampmanufacturerstrigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER settimestampmanufacturerstrigger BEFORE INSERT OR UPDATE ON manufacturers FOR EACH ROW EXECUTE PROCEDURE settimestamp();


--
-- TOC entry 2618 (class 2620 OID 24485)
-- Dependencies: 214 277 2625
-- Name: settimestampnetworkinterfacestrigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER settimestampnetworkinterfacestrigger BEFORE INSERT OR UPDATE ON "networkInterfaces" FOR EACH ROW EXECUTE PROCEDURE settimestamp();


--
-- TOC entry 2621 (class 2620 OID 24483)
-- Dependencies: 277 216 2625
-- Name: settimestampnetworksubnetstrigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER settimestampnetworksubnetstrigger BEFORE INSERT OR UPDATE ON "networkSubnets" FOR EACH ROW EXECUTE PROCEDURE settimestamp();


--
-- TOC entry 2576 (class 2620 OID 24496)
-- Dependencies: 277 145 2625
-- Name: settimestamprackmodelstrigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER settimestamprackmodelstrigger BEFORE INSERT OR UPDATE ON "rackModels" FOR EACH ROW EXECUTE PROCEDURE settimestamp();


--
-- TOC entry 2578 (class 2620 OID 24492)
-- Dependencies: 277 146 2625
-- Name: settimestamprackstrigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER settimestamprackstrigger BEFORE INSERT OR UPDATE ON racks FOR EACH ROW EXECUTE PROCEDURE settimestamp();


--
-- TOC entry 2575 (class 2620 OID 24497)
-- Dependencies: 277 143 2625
-- Name: settimestamproomstrigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER settimestamproomstrigger BEFORE INSERT OR UPDATE ON rooms FOR EACH ROW EXECUTE PROCEDURE settimestamp();


--
-- TOC entry 2593 (class 2620 OID 24471)
-- Dependencies: 177 277 2625
-- Name: settimestampservicetypestrigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER settimestampservicetypestrigger BEFORE INSERT OR UPDATE ON "serviceTypes" FOR EACH ROW EXECUTE PROCEDURE settimestamp();


--
-- TOC entry 2594 (class 2620 OID 24469)
-- Dependencies: 179 277 2625
-- Name: settimestampstatusestrigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER settimestampstatusestrigger BEFORE INSERT OR UPDATE ON statuses FOR EACH ROW EXECUTE PROCEDURE settimestamp();


--
-- TOC entry 2602 (class 2620 OID 24475)
-- Dependencies: 187 277 2625
-- Name: settimestampstoragesystemstrigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER settimestampstoragesystemstrigger BEFORE INSERT OR UPDATE ON "storageSystems" FOR EACH ROW EXECUTE PROCEDURE settimestamp();


--
-- TOC entry 2588 (class 2620 OID 24486)
-- Dependencies: 167 277 2625
-- Name: settimestampsystemstrigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER settimestampsystemstrigger BEFORE INSERT OR UPDATE ON systems FOR EACH ROW EXECUTE PROCEDURE settimestamp();


--
-- TOC entry 2603 (class 2620 OID 24474)
-- Dependencies: 191 277 2625
-- Name: settimestamptapedrivestrigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER settimestamptapedrivestrigger BEFORE INSERT OR UPDATE ON "tapeDrives" FOR EACH ROW EXECUTE PROCEDURE settimestamp();


--
-- TOC entry 2606 (class 2620 OID 24476)
-- Dependencies: 277 193 2625
-- Name: settimestamptapeserverstrigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER settimestamptapeserverstrigger BEFORE INSERT OR UPDATE ON "tapeServers" FOR EACH ROW EXECUTE PROCEDURE settimestamp();


--
-- TOC entry 2595 (class 2620 OID 24470)
-- Dependencies: 181 277 2625
-- Name: settimestampteamstrigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER settimestampteamstrigger BEFORE INSERT OR UPDATE ON teams FOR EACH ROW EXECUTE PROCEDURE settimestamp();


--
-- TOC entry 2582 (class 2620 OID 24495)
-- Dependencies: 277 152 2625
-- Name: settimestampvendorstrigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER settimestampvendorstrigger BEFORE INSERT OR UPDATE ON vendors FOR EACH ROW EXECUTE PROCEDURE settimestamp();


--
-- TOC entry 2597 (class 2620 OID 24473)
-- Dependencies: 185 277 2625
-- Name: settimestampvirtualorganisationstrigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER settimestampvirtualorganisationstrigger BEFORE INSERT OR UPDATE ON "virtualOrganisations" FOR EACH ROW EXECUTE PROCEDURE settimestamp();


--
-- TOC entry 2581 (class 2620 OID 24456)
-- Dependencies: 278 152 152 2625
-- Name: vaildemailaddresstrigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER vaildemailaddresstrigger BEFORE INSERT OR UPDATE OF "vendorEmailAddress" ON vendors FOR EACH ROW EXECUTE PROCEDURE vaildemailaddress();


--
-- TOC entry 2547 (class 2606 OID 24084)
-- Dependencies: 2452 181 183 2625
-- Name: admins_teamId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY admins
    ADD CONSTRAINT "admins_teamId_fkey" FOREIGN KEY ("teamId") REFERENCES teams(id);


--
-- TOC entry 2568 (class 2606 OID 24341)
-- Dependencies: 2498 209 205 2625
-- Name: aliases_domainId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY aliases
    ADD CONSTRAINT "aliases_domainId_fkey" FOREIGN KEY ("domainId") REFERENCES domains(id);


--
-- TOC entry 2565 (class 2606 OID 24284)
-- Dependencies: 201 199 2488 2625
-- Name: databaseServers_databaseTypeId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "databaseServers"
    ADD CONSTRAINT "databaseServers_databaseTypeId_fkey" FOREIGN KEY ("databaseTypeId") REFERENCES "databaseTypes"(id);


--
-- TOC entry 2564 (class 2606 OID 24279)
-- Dependencies: 167 2430 201 2625
-- Name: databaseServers_systemId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "databaseServers"
    ADD CONSTRAINT "databaseServers_systemId_fkey" FOREIGN KEY ("systemId") REFERENCES systems(id);


--
-- TOC entry 2546 (class 2606 OID 24031)
-- Dependencies: 173 2440 175 2625
-- Name: diskPools_castorInstanceId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "diskPools"
    ADD CONSTRAINT "diskPools_castorInstanceId_fkey" FOREIGN KEY ("castorInstanceId") REFERENCES "castorInstances"(id);


--
-- TOC entry 2534 (class 2606 OID 23888)
-- Dependencies: 2416 160 162 2625
-- Name: hardwareModelAttributes_hardwareModelAttributeTypeId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "hardwareModelAttributes"
    ADD CONSTRAINT "hardwareModelAttributes_hardwareModelAttributeTypeId_fkey" FOREIGN KEY ("hardwareModelAttributeTypeId") REFERENCES "hardwareModelAttributeTypes"(id);


--
-- TOC entry 2535 (class 2606 OID 23893)
-- Dependencies: 2414 162 158 2625
-- Name: hardwareModelAttributes_hardwareModelId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "hardwareModelAttributes"
    ADD CONSTRAINT "hardwareModelAttributes_hardwareModelId_fkey" FOREIGN KEY ("hardwareModelId") REFERENCES "hardwareModels"(id);


--
-- TOC entry 2532 (class 2606 OID 23856)
-- Dependencies: 2412 156 158 2625
-- Name: hardwareModels_hardwareModelClassId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "hardwareModels"
    ADD CONSTRAINT "hardwareModels_hardwareModelClassId_fkey" FOREIGN KEY ("hardwareModelClassId") REFERENCES "hardwareModelClasses"(id);


--
-- TOC entry 2533 (class 2606 OID 23861)
-- Dependencies: 158 154 2408 2625
-- Name: hardwareModels_manufacturerId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "hardwareModels"
    ADD CONSTRAINT "hardwareModels_manufacturerId_fkey" FOREIGN KEY ("manufacturerId") REFERENCES manufacturers(id);


--
-- TOC entry 2536 (class 2606 OID 23921)
-- Dependencies: 166 158 2414 2625
-- Name: hardwares_hardwareModelId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY hardwares
    ADD CONSTRAINT "hardwares_hardwareModelId_fkey" FOREIGN KEY ("hardwareModelId") REFERENCES "hardwareModels"(id);


--
-- TOC entry 2537 (class 2606 OID 23926)
-- Dependencies: 166 2424 164 2625
-- Name: hardwares_hardwareStatusId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY hardwares
    ADD CONSTRAINT "hardwares_hardwareStatusId_fkey" FOREIGN KEY ("hardwareStatusId") REFERENCES "hardwareStatuses"(id);


--
-- TOC entry 2561 (class 2606 OID 24242)
-- Dependencies: 197 2440 173 2625
-- Name: headNodes_castorInstanceId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "headNodes"
    ADD CONSTRAINT "headNodes_castorInstanceId_fkey" FOREIGN KEY ("castorInstanceId") REFERENCES "castorInstances"(id);


--
-- TOC entry 2562 (class 2606 OID 24247)
-- Dependencies: 195 197 2480 2625
-- Name: headNodes_primaryFunctionTypeId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "headNodes"
    ADD CONSTRAINT "headNodes_primaryFunctionTypeId_fkey" FOREIGN KEY ("primaryFunctionTypeId") REFERENCES "functionTypes"(id);


--
-- TOC entry 2563 (class 2606 OID 24252)
-- Dependencies: 195 2480 197 2625
-- Name: headNodes_secondaryFunctionTypeId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "headNodes"
    ADD CONSTRAINT "headNodes_secondaryFunctionTypeId_fkey" FOREIGN KEY ("secondaryFunctionTypeId") REFERENCES "functionTypes"(id);


--
-- TOC entry 2560 (class 2606 OID 24237)
-- Dependencies: 167 197 2430 2625
-- Name: headNodes_systemId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "headNodes"
    ADD CONSTRAINT "headNodes_systemId_fkey" FOREIGN KEY ("systemId") REFERENCES systems(id);


--
-- TOC entry 2573 (class 2606 OID 24422)
-- Dependencies: 2514 218 214 2625
-- Name: hostAddresses_networkInterfaceId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "hostAddresses"
    ADD CONSTRAINT "hostAddresses_networkInterfaceId_fkey" FOREIGN KEY ("networkInterfaceId") REFERENCES "networkInterfaces"(id);


--
-- TOC entry 2574 (class 2606 OID 24432)
-- Dependencies: 216 218 2522 2625
-- Name: hostAddresses_networkSubnetId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "hostAddresses"
    ADD CONSTRAINT "hostAddresses_networkSubnetId_fkey" FOREIGN KEY ("networkSubnetId") REFERENCES "networkSubnets"(id);


--
-- TOC entry 2570 (class 2606 OID 24649)
-- Dependencies: 210 2507 209 2625
-- Name: hostnamesAliases_aliasId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "hostnamesAliases"
    ADD CONSTRAINT "hostnamesAliases_aliasId_fkey" FOREIGN KEY ("aliasId") REFERENCES aliases(id) ON DELETE CASCADE;


--
-- TOC entry 2569 (class 2606 OID 24644)
-- Dependencies: 210 207 2503 2625
-- Name: hostnamesAliases_hostnameId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "hostnamesAliases"
    ADD CONSTRAINT "hostnamesAliases_hostnameId_fkey" FOREIGN KEY ("hostnameId") REFERENCES hostnames(id) ON DELETE CASCADE;


--
-- TOC entry 2566 (class 2606 OID 24324)
-- Dependencies: 207 205 2498 2625
-- Name: hostnames_domainId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY hostnames
    ADD CONSTRAINT "hostnames_domainId_fkey" FOREIGN KEY ("domainId") REFERENCES domains(id);


--
-- TOC entry 2567 (class 2606 OID 24503)
-- Dependencies: 2526 218 207 2625
-- Name: hostnames_hostAddressId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY hostnames
    ADD CONSTRAINT "hostnames_hostAddressId_fkey" FOREIGN KEY ("hostAddressId") REFERENCES "hostAddresses"(id) ON DELETE CASCADE;


--
-- TOC entry 2544 (class 2606 OID 23993)
-- Dependencies: 2428 166 171 2625
-- Name: interventionActions_hardwareId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "interventionActions"
    ADD CONSTRAINT "interventionActions_hardwareId_fkey" FOREIGN KEY ("hardwareId") REFERENCES hardwares(id);


--
-- TOC entry 2543 (class 2606 OID 23988)
-- Dependencies: 169 2432 171 2625
-- Name: interventionActions_interventionActionClassId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "interventionActions"
    ADD CONSTRAINT "interventionActions_interventionActionClassId_fkey" FOREIGN KEY ("interventionActionClassId") REFERENCES "interventionActionClasses"(id);


--
-- TOC entry 2545 (class 2606 OID 23998)
-- Dependencies: 167 2430 171 2625
-- Name: interventionActions_systemId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "interventionActions"
    ADD CONSTRAINT "interventionActions_systemId_fkey" FOREIGN KEY ("systemId") REFERENCES systems(id);


--
-- TOC entry 2572 (class 2606 OID 24387)
-- Dependencies: 212 2512 214 2625
-- Name: networkInterfaces_networkInterfaceTypeId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "networkInterfaces"
    ADD CONSTRAINT "networkInterfaces_networkInterfaceTypeId_fkey" FOREIGN KEY ("networkInterfaceTypeId") REFERENCES "networkInterfaceTypes"(id);


--
-- TOC entry 2571 (class 2606 OID 24382)
-- Dependencies: 214 167 2430 2625
-- Name: networkInterfaces_systemId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "networkInterfaces"
    ADD CONSTRAINT "networkInterfaces_systemId_fkey" FOREIGN KEY ("systemId") REFERENCES systems(id);


--
-- TOC entry 2531 (class 2606 OID 23786)
-- Dependencies: 145 146 2396 2625
-- Name: racks_rackModelId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY racks
    ADD CONSTRAINT "racks_rackModelId_fkey" FOREIGN KEY ("rackModelId") REFERENCES "rackModels"(id);


--
-- TOC entry 2530 (class 2606 OID 23781)
-- Dependencies: 143 2394 146 2625
-- Name: racks_roomId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY racks
    ADD CONSTRAINT "racks_roomId_fkey" FOREIGN KEY ("roomId") REFERENCES rooms(id);


--
-- TOC entry 2550 (class 2606 OID 24133)
-- Dependencies: 2450 187 179 2625
-- Name: storageSystems_currentStatusId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "storageSystems"
    ADD CONSTRAINT "storageSystems_currentStatusId_fkey" FOREIGN KEY ("currentStatusId") REFERENCES statuses(id);


--
-- TOC entry 2552 (class 2606 OID 24143)
-- Dependencies: 187 181 2452 2625
-- Name: storageSystems_currentTeamId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "storageSystems"
    ADD CONSTRAINT "storageSystems_currentTeamId_fkey" FOREIGN KEY ("currentTeamId") REFERENCES teams(id);


--
-- TOC entry 2555 (class 2606 OID 24158)
-- Dependencies: 187 175 2444 2625
-- Name: storageSystems_diskPoolId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "storageSystems"
    ADD CONSTRAINT "storageSystems_diskPoolId_fkey" FOREIGN KEY ("diskPoolId") REFERENCES "diskPools"(id);


--
-- TOC entry 2551 (class 2606 OID 24138)
-- Dependencies: 179 187 2450 2625
-- Name: storageSystems_normalStatusId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "storageSystems"
    ADD CONSTRAINT "storageSystems_normalStatusId_fkey" FOREIGN KEY ("normalStatusId") REFERENCES statuses(id);


--
-- TOC entry 2553 (class 2606 OID 24148)
-- Dependencies: 177 187 2446 2625
-- Name: storageSystems_serviceTypeId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "storageSystems"
    ADD CONSTRAINT "storageSystems_serviceTypeId_fkey" FOREIGN KEY ("serviceTypeId") REFERENCES "serviceTypes"(id);


--
-- TOC entry 2549 (class 2606 OID 24128)
-- Dependencies: 167 2430 187 2625
-- Name: storageSystems_systemId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "storageSystems"
    ADD CONSTRAINT "storageSystems_systemId_fkey" FOREIGN KEY ("systemId") REFERENCES systems(id);


--
-- TOC entry 2554 (class 2606 OID 24153)
-- Dependencies: 187 185 2460 2625
-- Name: storageSystems_virtualOrganisationId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "storageSystems"
    ADD CONSTRAINT "storageSystems_virtualOrganisationId_fkey" FOREIGN KEY ("virtualOrganisationId") REFERENCES "virtualOrganisations"(id);


--
-- TOC entry 2540 (class 2606 OID 23950)
-- Dependencies: 2400 167 148 2625
-- Name: systems_categoryId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY systems
    ADD CONSTRAINT "systems_categoryId_fkey" FOREIGN KEY ("categoryId") REFERENCES categories(id);


--
-- TOC entry 2541 (class 2606 OID 23955)
-- Dependencies: 150 167 2402 2625
-- Name: systems_lifestageId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY systems
    ADD CONSTRAINT "systems_lifestageId_fkey" FOREIGN KEY ("lifestageId") REFERENCES lifestages(id);


--
-- TOC entry 2542 (class 2606 OID 23960)
-- Dependencies: 167 154 2408 2625
-- Name: systems_manufacturerId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY systems
    ADD CONSTRAINT "systems_manufacturerId_fkey" FOREIGN KEY ("manufacturerId") REFERENCES manufacturers(id);


--
-- TOC entry 2539 (class 2606 OID 23945)
-- Dependencies: 2398 167 146 2625
-- Name: systems_rackId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY systems
    ADD CONSTRAINT "systems_rackId_fkey" FOREIGN KEY ("rackId") REFERENCES racks(id);


--
-- TOC entry 2538 (class 2606 OID 23940)
-- Dependencies: 167 2404 152 2625
-- Name: systems_vendorId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY systems
    ADD CONSTRAINT "systems_vendorId_fkey" FOREIGN KEY ("vendorId") REFERENCES vendors(id);


--
-- TOC entry 2556 (class 2606 OID 24183)
-- Dependencies: 2470 189 191 2625
-- Name: tapeDrives_tapeDriveTypeId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "tapeDrives"
    ADD CONSTRAINT "tapeDrives_tapeDriveTypeId_fkey" FOREIGN KEY ("tapeDriveTypeId") REFERENCES "tapeDriveTypes"(id);


--
-- TOC entry 2557 (class 2606 OID 24200)
-- Dependencies: 2430 167 193 2625
-- Name: tapeServers_systemId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "tapeServers"
    ADD CONSTRAINT "tapeServers_systemId_fkey" FOREIGN KEY ("systemId") REFERENCES systems(id);


--
-- TOC entry 2559 (class 2606 OID 24210)
-- Dependencies: 2472 193 191 2625
-- Name: tapeServers_typeDriveId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "tapeServers"
    ADD CONSTRAINT "tapeServers_typeDriveId_fkey" FOREIGN KEY ("typeDriveId") REFERENCES "tapeDrives"(id);


--
-- TOC entry 2558 (class 2606 OID 24205)
-- Dependencies: 185 193 2460 2625
-- Name: tapeServers_virtualOrganisationId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "tapeServers"
    ADD CONSTRAINT "tapeServers_virtualOrganisationId_fkey" FOREIGN KEY ("virtualOrganisationId") REFERENCES "virtualOrganisations"(id);


--
-- TOC entry 2548 (class 2606 OID 24101)
-- Dependencies: 185 173 2440 2625
-- Name: virtualOrganisations_castorInstanceId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "virtualOrganisations"
    ADD CONSTRAINT "virtualOrganisations_castorInstanceId_fkey" FOREIGN KEY ("castorInstanceId") REFERENCES "castorInstances"(id);


-- Completed on 2013-08-14 17:36:34 BST

--
-- PostgreSQL database dump complete
--

