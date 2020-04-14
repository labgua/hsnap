<?

function rpc_hello(){
	echo "lettura di d1:" . $_POST["d1"] . "\n";
	if( $_POST["d1"] == "ok" ) echo "stabbene!";
	else echo "non va bene...";
	echo "\n";
}

function rpc_synczip(){

	$OUT = "";

	chdir(ROOT_SERVER_PATH);

	$namefile = $_POST["file"];
	$path = $_POST["path"];

	$zip = new ZipArchive;

	$zip_snapshot_path = ROOT_SERVER_PATH . $namefile;
	$extract_to_path = ROOT_SERVER_PATH . $path;

	$OUT .= "syncZip: path_zip=$zip_snapshot_path\n";

	if( $_POST["multipart"] == FALSE ){
		if ($zip->open($zip_snapshot_path) === TRUE) {
			$zip->extractTo($extract_to_path);
			$zip->close();
			$OUT .= "syncZip: extract to $extract_to_path, ok\n";
		} else {
		    $OUT .= "syncZip: extract to $extract_to_path, failed\n";
		    die($OUT);
		}	
	}
	else{ //multipart
		$OUT .= "syncZip: multipart extraction...";
		$files = scandir(ROOT_SERVER_PATH . $namefile);
		foreach ($files as $f) { // per ogni file....
			if( strpos($f, '.zip') !== false){  // se è un file zip ....
				if ($zip->open(ROOT_SERVER_PATH . "$namefile/$f") === TRUE) { // aprilo...
					$zip->extractTo($extract_to_path); // estrailo nella cartella di destinazione
					$zip->close(); // chiudilo...

					unlink(ROOT_SERVER_PATH . "$namefile/$f"); // cancellalo (alla prossima chiamata PHP prenderà il prossimo)
					
					$OUT .= "syncZip: extract to $extract_to_path part:$namefile/$f, ok\n";
				} else {
				    $OUT .= "syncZip: extract to $extract_to_path part:$namefile/$f, failed\n";
				    die($OUT);
				}
			}
		}
	}


	//gestione cancellazione file
	chdir( $extract_to_path );
	$OUT .= "syncZip: change dir to $extract_to_path\n";
	if( file_exists(".todelete") ){
		$OUT .= "syncZip: found .todelete ...\n";
		$todelete = fopen(".todelete","r");
		$deleted = fopen(".deleted", "w");
		while( !feof($todelete) ){
			$target = trim( fgets($todelete) );
			//if( is_file ($target) ) unlink($target);
			//if( is_dir($target) ) rmrf($target);
			unlink($target);
			fwrite($deleted, "$target\n");
			// else ignoralo...
		}
		fclose($file);
		fclose($deleted);

		unlink(".todelete");
		unlink(".deleted");

		$OUT .= "syncZip: files deleted, ok\n";
	}
	else{
		$OUT .= "syncZip: not found .todelete, nothing to delete?\n";
	}

	echo $OUT;
}