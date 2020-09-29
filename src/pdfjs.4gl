IMPORT util
IMPORT os
CONSTANT FILE1 = "hello.pdf"
CONSTANT FILE2 = "radstation.pdf"
DEFINE m_debug STRING
MAIN
	DEFINE w, err, creator, author STRING
	DEFINE fileLocation STRING
	LET fileLocation = fgl_getEnv("FILELOC")

	CALL check_prerequisites()
	OPEN FORM f FROM "pdfjs"
	DISPLAY FORM f

	CALL fgl_setTitle( SFMT( "WC PDF Demo: %1", os.path.mtime( "pdfjs.42m" ) ))

	CALL debug( SFMT("FGLIMAGEPATH: %1\nFILELOC: %2", fgl_getEnv("FGLIMAGEPATH"), fgl_getEnv("FILELOC") ) )
	CALL debug( SFMT("USE_PUBLIC: %1\nFGL_PUBLIC_DIR: %2\nFGL_PUBLIC_IMAGEPATH: %3", fgl_getenv("USE_PUBLIC"), fgl_getenv("FGL_PUBLIC_DIR"), fgl_getenv("FGL_PUBLIC_IMAGEPATH")) )

	--DISPLAY os.path.join(fileLocation,"tumbleweed.gif") TO img
	DISPLAY ui.Interface.filenameToURI( os.path.join(fileLocation,"tumbleweed.gif") ) TO img

	INPUT BY NAME w, m_debug WITHOUT DEFAULTS ATTRIBUTE(UNBUFFERED, ACCEPT = FALSE)
		BEFORE INPUT
			CALL DIALOG.setActionHidden("error", 1)
			CALL displayPDF( os.path.join(fileLocation, FILE1) )
		ON ACTION file2
			CALL displayPDF( os.path.join(fileLocation, FILE2) )
		ON ACTION file1
			CALL displayPDF( os.path.join(fileLocation, FILE1) )
		ON ACTION showcreator
			CALL ui.interface.frontcall("webcomponent", "call", ["formonly.w", "getCreator"], [creator])
			MESSAGE "creator:", creator
		ON ACTION showauthor
			CALL ui.interface.frontcall("webcomponent", "call", ["formonly.w", "getAuthor"], [author])
			MESSAGE "author:", author
		ON ACTION error
			CALL ui.interface.frontcall("webcomponent", "call", ["formonly.w", "getError"], [err])
			ERROR SFMT("Failed at js side with:%1", err)
		ON ACTION showenv
			ERROR "public_dir:", fgl_getenv("FGL_PUBLIC_DIR"), ",\npublic_url_prefix:", fgl_getenv("FGL_PUBLIC_URL_PREFIX"),
					",\npublic_image:", fgl_getenv("FGL_PUBLIC_IMAGEPATH"), ",\npwd:", os.Path.pwd(), ",\nFGL_PRIVATE_DIR:",
					fgl_getenv("FGL_PRIVATE_DIR")
			DISPLAY "public_dir:", fgl_getenv("FGL_PUBLIC_DIR"), ",\npublic_url_prefix:", fgl_getenv("FGL_PUBLIC_URL_PREFIX"),
					",\npublic_image:", fgl_getenv("FGL_PUBLIC_IMAGEPATH"), ",\npwd:", os.Path.pwd(), ",\nFGL_PRIVATE_DIR:",
					fgl_getenv("FGL_PRIVATE_DIR")
			RUN "echo `env | grep FGL`"
		ON ACTION cancel EXIT INPUT
		ON ACTION close EXIT INPUT
	END INPUT
END MAIN
--------------------------------------------------------------------------------------------------------------
FUNCTION copyToPublic(fname)
	DEFINE fname, pubdir, pubimgpath, pubname STRING
	DEFINE remoteName STRING
	DEFINE sepIdx INT
	DEFINE use_public BOOLEAN

	DISPLAY fname TO file
  --enable the copy to a public location
	LET use_public = fgl_getenv("USE_PUBLIC") IS NOT NULL

	--GAS sets this variables, to they are only available in GAS mode
	LET pubdir = fgl_getenv("FGL_PUBLIC_DIR")
	LET pubimgpath = fgl_getenv("FGL_PUBLIC_IMAGEPATH")
	IF pubdir IS NOT NULL AND os.Path.exists(pubdir) THEN
		--just use the first sub dir in the path if we have more than one
		--the default is "common"
		IF (sepIdx := pubimgpath.getIndexOf(os.Path.pathSeparator(), 1)) > 0 THEN
			LET pubimgpath = pubimgpath.subString(1, sepIdx - 1)
		END IF
		LET pubdir = os.Path.join(pubdir, pubimgpath)
		LET pubname = os.Path.join(pubdir, os.Path.baseName(fname))
		--copy our image to the GAS public dir
		--which means anybody knowing the file name can access it
		--if our file name is hello.pdf the http name is then http://localhost:xxx/ua/i/common/hello.pdf?t=xxxxxxx
		IF use_public THEN
			DISPLAY pubname TO file
			IF NOT os.path.exists( pubdir ) THEN -- check to see if target sub folder exists
				IF os.path.mkdir( pubdir ) THEN -- attempt to create the target sub folder.
					CALL debug(SFMT("%1 didn't exist, created.", pubdir ))
				ELSE
					CALL debug(SFMT("%1 didn't exist, create failed %2", pubdir, ERR_GET(STATUS) ))
					RETURN NULL
				END IF
			END IF
			IF NOT os.path.exists( pubname ) THEN -- only copy if doesn't already exists in target location.
				CALL debug( SFMT("Copy %1 to %2", fname, pubname ) )
				IF NOT os.Path.copy(fname, pubname) THEN
					CALL debug(  SFMT("Copy failed: %1", ERR_GET(STATUS)) )
					RETURN NULL
				END IF
			ELSE
				CALL debug( SFMT("File already exists in public location: %1", pubname) )
			END IF
			LET fname = os.Path.baseName(fname) -- vital to remove any path from file name here!
		ELSE
			--remove any potential leftovers
			--CALL os.Path.delete(pubname) RETURNING status
		END IF
	END IF
	LET remoteName = ui.Interface.filenameToURI(fname)
	RETURN remoteName
END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION displayPDF(fname)
	DEFINE fname, remoteName STRING
	LET remoteName = copyToPublic(fname)
	CALL debug( SFMT("Local File: %1 ( %2 )", fname, IIF(os.path.exists(fname),"Exists","Missing!")))
	IF remoteName.subString(1,4) = "http" THEN
		CALL debug( SFMT("Remote File: %1", remoteName ) )
	ELSE
		CALL debug( SFMT("Remote File: %1 ( %2 )", remoteName, IIF(os.path.exists(remoteName),"Exists","Missing!") ) )
	END IF
	CALL debug(SFMT("Attempting to display: %1", remoteName ))
	DISPLAY remoteName TO url
	CALL ui.interface.frontcall("webcomponent", "call", ["formonly.w", "displayPDF", remoteName], [])
END FUNCTION
--------------------------------------------------------------------------------------------------------------
-- OS packages required to download and patch the PDF js library.
FUNCTION check_prerequisites()
	DEFINE code INT
	RUN "curl --help > /dev/null" RETURNING code
	IF code THEN
		DISPLAY "SKIP test for platforms not having curl"
		EXIT PROGRAM 1
	END IF
	RUN "patch --help > /dev/null" RETURNING code
	IF code THEN
		DISPLAY "SKIP test for platforms not having patch"
		EXIT PROGRAM 1
	END IF
{	RUN "make download_and_patch > /dev/null" RETURNING code
	IF code THEN
		DISPLAY "SKIP test: download and patch failed"
		EXIT PROGRAM 1
	END IF}
END FUNCTION
--------------------------------------------------------------------------------------------------------------
-- My debug display function
FUNCTION debug(l_msg STRING)
	DISPLAY l_msg
	LET m_debug = m_debug.append(l_msg || "\n")
END FUNCTION
