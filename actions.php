<?

function rpc_hello(){
	echo "lettura di d1:" . $_POST["d1"] . "\n";
	if( $_POST["d1"] == "ok" ) echo "stabbene!";
	else echo "non va bene...";
	echo "\n";
}

function rpc_synczip(){

	chdir("..");

	$OUT = "";

	$namefile = $_POST["file"];
	$path = $_POST["path"];

	$zip = new ZipArchive;

	if( $_POST["multipart"] == FALSE ){
		if ($zip->open($namefile) === TRUE) {
			$zip->extractTo($path);
			$zip->close();
			$OUT .= "syncZip: extract action, ok\n";
		} else {
		    $OUT .= "syncZip: extract action, failed\n";
		    die($OUT);
		}	
	}
	else{ //multipart
		$OUT .= "syncZip: multipart extraction...";
		$files = scandir($namefile);
		foreach ($files as $f) { // per ogni file....
			if( strpos($f, '.zip') !== false){  // se è un file zip ....
				if ($zip->open("$namefile/$f") === TRUE) { // aprilo...
					$zip->extractTo($path); // estrailo nella cartella di destinazione
					$zip->close(); // chiudilo...

					unlink("$namefile/$f"); // cancellalo (alla prossima chiamata PHP prenderà il prossimo)
					
					$OUT .= "syncZip: extract action part:$namefile/$f, ok\n";
				} else {
				    $OUT .= "syncZip: extract action, failed\n";
				    die($OUT);
				}
			}
		}
	}


	//gestione cancellazione file
	chdir($path);
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

		$OUT .= "syncZip: files deleted, ok\n";
	}
	else{
		$OUT .= "syncZip: not found .todelete, nothing to delete?\n";
	}

	echo $OUT;
}