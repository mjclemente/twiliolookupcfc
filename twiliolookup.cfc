/**
* twiliolookupcfc
* Copyright 2020  Matthew J. Clemente, John Berquist
* Licensed under MIT (https://mit-license.org)
*/
component displayname="twiliolookupcfc"  {

    variables._twiliolookupcfc_version = '1.0.0';

    public any function init(
        string accountSid = '',
        string authToken = '',
        string baseUrl = "https://lookups.twilio.com/v1",
        boolean includeRaw = false,
        numeric httpTimeout = 50
    ) {

        structAppend( variables, arguments );

        //map sensitive args to env variables or java system props
        var secrets = {
            'accountSid': 'TWILIO_ACCOUNT_SID',
            'authToken': 'TWILIO_AUTH_TOKEN'
        };
        var system = createObject( 'java', 'java.lang.System' );

        for ( var key in secrets ) {
            //arguments are top priority
            if ( variables[ key ].len() ) {
                continue;
            }

            //check environment variables
            var envValue = system.getenv( secrets[ key ] );
            if ( !isNull( envValue ) && envValue.len() ) {
                variables[ key ] = envValue;
                continue;
            }

            //check java system properties
            var propValue = system.getProperty( secrets[ key ] );
            if ( !isNull( propValue ) && propValue.len() ) {
                variables[ key ] = propValue;
            }
        }

        //declare file fields to be handled via multipart/form-data **Important** this is not applicable if payload is application/json
        variables.fileFields = [];

        return this;
    }

    /**
    * @docs https://www.twilio.com/docs/lookup/api#lookup-a-phone-number
    * @hint Returns phone number information matching the specified request. Formatting information is standard. Carrier, Caller Name, and phone number type information can be requested, in addition to using Add-ons to access 3rd party data sources.
    * @type can be: `carrier` or `caller-name`. Defaults to null. For both, pass in an array with both values.
    */
    public struct function phoneNumber( required string phoneNumber, string CountryCode = '', any Type = '', string AddOns = '', struct AddOnsData = {} ) {
      var params = {}
      if( len( CountryCode ) ){
        params["CountryCode"] = CountryCode;
      }
      if( len( Type ) ){
        params["Type"] = Type;
      }
      if( len( AddOns ) ){
        params["AddOns"] = AddOns;
      }
      if( !AddOnsData.isEmpty() ){
        params[" AddOnsData"] = structToQueryString(  AddOnsData );
      }
      return apiCall( 'GET', '/PhoneNumbers/#phoneNumber#', params );
    }

    /**
    * @hint Convenience method for looking up carrier information about the number. Set's the `Type` parameter in the lookup to `carrier`
    */
    public struct function carrier( required string phoneNumber, string CountryCode = '', string AddOns = '', struct AddOnsData = {} ) {
      return this.phoneNumber( phoneNumber = phoneNumber, CountryCode = CountryCode, Type = 'carrier', AddOns = AddOns, AddOnsData = AddOnsData );
    }

    /**
    * @hint Convenience method for looking up caller information. Set's the `Type` parameter in the lookup to `caller-name`
    */
    public struct function caller( required string phoneNumber, string CountryCode = '', string AddOns = '', struct AddOnsData = {} ) {
      return this.phoneNumber( phoneNumber = phoneNumber, CountryCode = CountryCode, type = 'caller-name', AddOns = AddOns, AddOnsData = AddOnsData );
    }

      /**
    * @hint Convenience method for looking up both caller and carrier information. Set's the `Type` parameter in the lookup to `['carrier','caller-name']`
    */
    public struct function callerAndCarrier( required string phoneNumber, string CountryCode = '', string AddOns = '', struct AddOnsData = {} ) {
      return this.phoneNumber( phoneNumber = phoneNumber, CountryCode = CountryCode, type = ['carrier','caller-name'], AddOns = AddOns, AddOnsData = AddOnsData );
    }

    // PRIVATE FUNCTIONS
    private struct function apiCall(
        required string httpMethod,
        required string path,
        struct queryParams = { },
        any payload = '',
        struct headers = { }
    ) {

        var fullApiPath = variables.baseUrl & path;
        var requestHeaders = getBaseHttpHeaders();
        requestHeaders.append( headers, true );

        var requestStart = getTickCount();
        var apiResponse = makeHttpRequest( httpMethod = httpMethod, path = fullApiPath, queryParams = queryParams, headers = requestHeaders, payload = payload );

        var result = {
            'responseTime' = getTickCount() - requestStart,
            'statusCode' = listFirst( apiResponse.statuscode, " " ),
            'statusText' = listRest( apiResponse.statuscode, " " ),
            'headers' = apiResponse.responseheader
        };

        var parsedFileContent = {};

        // Handle response based on mimetype
        var mimeType = apiResponse.mimetype ?: requestHeaders[ 'Content-Type' ];

        if ( mimeType == 'application/json' && isJson( apiResponse.fileContent ) ) {
            parsedFileContent = deserializeJSON( apiResponse.fileContent );
        } else if ( mimeType.listLast( '/' ) == 'xml' && isXml( apiResponse.fileContent ) ) {
            parsedFileContent = xmlToStruct( apiResponse.fileContent );
        } else {
            parsedFileContent = apiResponse.fileContent;
        }

        //can be customized by API integration for how errors are returned
        //if ( result.statusCode >= 400 ) {}

        //stored in data, because some responses are arrays and others are structs
        result[ 'data' ] = parsedFileContent;

        if ( variables.includeRaw ) {
            result[ 'raw' ] = {
                'method' : ucase( httpMethod ),
                'path' : fullApiPath,
                'params' : parseQueryParams( queryParams ),
                'payload' : parseBody( payload ),
                'response' : apiResponse.fileContent
            };
        }

        return result;
    }

    private struct function getBaseHttpHeaders() {
        return {
            'Accept' : 'application/json',
            'Content-Type' : 'application/json',
            'User-Agent' : 'twiliolookupcfc/#variables._twiliolookupcfc_version# (ColdFusion)'
        };
    }

    private any function makeHttpRequest(
        required string httpMethod,
        required string path,
        struct queryParams = { },
        struct headers = { },
        any payload = ''
    ) {
        var result = '';

        var fullPath = path & ( !queryParams.isEmpty()
            ? ( '?' & parseQueryParams( queryParams, false ) )
            : '' );

        cfhttp( url = fullPath, method = httpMethod, username = variables.accountSid, password = variables.authToken, result = 'result', timeout = variables.httpTimeout ) {

            if ( isJsonPayload( headers ) ) {

                var requestPayload = parseBody( payload );
                if ( isJSON( requestPayload ) ) {
                    cfhttpparam( type = "body", value = requestPayload );
                }

            } else if ( isFormPayload( headers ) ) {

                headers.delete( 'Content-Type' ); //Content Type added automatically by cfhttppparam

                for ( var param in payload ) {
                    if ( !variables.fileFields.contains( param ) ) {
                        cfhttpparam( type = 'formfield', name = param, value = payload[ param ] );
                    } else {
                        cfhttpparam( type = 'file', name = param, file = payload[ param ] );
                    }
                }

            }

            //handled last, to account for possible Content-Type header correction for forms
            var requestHeaders = parseHeaders( headers );
            for ( var header in requestHeaders ) {
                cfhttpparam( type = "header", name = header.name, value = header.value );
            }

        }
        return result;
    }

    /**
    * @hint convert the headers from a struct to an array
    */
    private array function parseHeaders( required struct headers ) {
        var sortedKeyArray = headers.keyArray();
        sortedKeyArray.sort( 'textnocase' );
        var processedHeaders = sortedKeyArray.map(
            function( key ) {
                return { name: key, value: trim( headers[ key ] ) };
            }
        );
        return processedHeaders;
    }

    /**
    * @hint converts the queryparam struct to a string, with optional encoding and the possibility for empty values being pass through as well. Modified so that array parameters will be included multiple times, following the docs: "To retrieve both types on information, specify this parameter twice; once with carrier and once with caller-name as the value."
    */
    private string function parseQueryParams( required struct queryParams, boolean encodeQueryParams = true, boolean includeEmptyValues = true ) {
        var sortedKeyArray = queryParams.keyArray();
        sortedKeyArray.sort( 'text' );

        var queryString = sortedKeyArray.reduce(
            function( queryString, queryParamKey ) {
                var encodedKey = encodeQueryParams
                    ? encodeUrl( queryParamKey )
                    : queryParamKey;
                if ( !isArray( queryParams[ queryParamKey ] ) ) {
                    var encodedValue = encodeQueryParams && len( queryParams[ queryParamKey ] )
                        ? encodeUrl( queryParams[ queryParamKey ] )
                        : queryParams[ queryParamKey ];
                    return queryString.listAppend( encodedKey & ( includeEmptyValues || len( encodedValue ) ? ( '=' & encodedValue ) : '' ), '&' );
                } else {
                    var parsedArrayParams = queryParams[ queryParamKey ].reduce(
                      ( result, item, index ) => {
                        var param = encodedKey;
                        if( includeEmptyValues || len( item ) ){
                          param &= "=";
                          param &= encodeQueryParams
                          ? encodeUrl( item )
                          : item;
                        }
                        return result.listAppend( param, '&' );
                      }, ''
                    );

                    return queryString.listAppend( parsedArrayParams, '&' );

                }
            }, ''
        );

        return queryString.len() ? queryString : '';
    }

    private string function parseBody( required any body ) {
        if ( isStruct( body ) || isArray( body ) ) {
            return serializeJson( body );
        } else if ( isJson( body ) ) {
            return body;
        } else {
            return '';
        }
    }

    private string function encodeUrl( required string str, boolean encodeSlash = true ) {
        var result = replacelist( urlEncodedFormat( str, 'utf-8' ), '%2D,%2E,%5F,%7E', '-,.,_,~' );
        if ( !encodeSlash ) {
            result = replace( result, '%2F', '/', 'all' );
        }
        return result;
    }

    /**
    * @hint helper to determine if body should be sent as JSON
    */
    private boolean function isJsonPayload( required struct headers ) {
        return headers[ 'Content-Type' ] == 'application/json';
    }

    /**
    * @hint helper to determine if body should be sent as form params
    */
    private boolean function isFormPayload( required struct headers ) {
        return arrayContains( [ 'application/x-www-form-urlencoded', 'multipart/form-data' ], headers[ 'Content-Type' ] );
    }

    /**
    *
    * Based on an (old) blog post and UDF from Raymond Camden
    * https://www.raymondcamden.com/2012/01/04/Converting-XML-to-JSON-My-exploration-into-madness/
    *
    */
    private struct function xmlToStruct( required any x ) {

        if ( isSimpleValue( x ) && isXml( x ) ) {
            x = xmlParse( x );
        }

        var s = {};

        if ( xmlGetNodeType( x ) == "DOCUMENT_NODE" ) {
            s[ structKeyList( x ) ] = xmlToStruct( x[ structKeyList( x ) ] );
        }

        if ( structKeyExists( x, "xmlAttributes" ) && !structIsEmpty( x.xmlAttributes ) ) {
            s.attributes = {};
            for ( var item in x.xmlAttributes ) {
                s.attributes[ item ] = x.xmlAttributes[ item ];
            }
        }

        if ( structKeyExists( x, 'xmlText' ) && x.xmlText.trim().len() ) {
            s.value = x.xmlText;
        }

        if ( structKeyExists( x, "xmlChildren" ) ) {

            for ( var xmlChild in x.xmlChildren ) {
                if ( structKeyExists( s, xmlChild.xmlname ) ) {

                    if ( !isArray( s[ xmlChild.xmlname ] ) ) {
                        var temp = s[ xmlChild.xmlname ];
                        s[ xmlChild.xmlname ] = [ temp ];
                    }

                    arrayAppend( s[ xmlChild.xmlname ], xmlToStruct( xmlChild ) );

                } else {

                    if ( structKeyExists( xmlChild, "xmlChildren" ) && arrayLen( xmlChild.xmlChildren ) ) {
                            s[ xmlChild.xmlName ] = xmlToStruct( xmlChild );
                    } else if ( structKeyExists( xmlChild, "xmlAttributes" ) && !structIsEmpty( xmlChild.xmlAttributes ) ) {
                        s[ xmlChild.xmlName ] = xmlToStruct( xmlChild );
                    } else {
                        s[ xmlChild.xmlName ] = xmlChild.xmlText;
                    }

                }

            }
        }

        return s;
    }

    /**
    *
    * Based on a CFLIB post by Erki Esken
    * https://cflib.org/udf/StructToQueryString
    *
    */
    private function structToQueryString( required struct struct ) {
      var qstr = "";
      var delim1 = "=";
      var delim2 = "&";
      for( var key in struct ) {
        qstr = ListAppend(qstr, key & delim1 & struct[key], delim2);
      }
      return qstr;
    }

}
