<?php
   //
   // Requires file config.php defining the following 5 variables
   //
   // $DB_HOST - Hostname of the mysql database server to connect to.
   // $DB_USER - Username to use to login to mysql
   // $DB_PASS - Password for logging into mysql
   // $DB_NAME - The name of the mysql database to use
   // $SALT - Secret salt value to be added to the name password before hashing
   //
   require_once('config.php');

   mb_http_output('utf-8');
   header('Content-type: text/plain; utf-8');

   $mysqli = new mysqli($DB_HOST, $DB_USER, $DB_PASS, $DB_NAME);
   $mysqli->connect;

   if ($mysqli->connect_errno) {
      echo "DB CONNECT FAILED";
      die();
   }

   if ($_GET['action'] == "geturl") {
      $domain = mysqli_real_escape_string($mysqli,urldecode($_GET['domain']));
   } else {
      $domain = mysqli_real_escape_string($mysqli,urldecode($_POST['domain']));
   }

   $password = mysqli_real_escape_string($mysqli,urldecode($_POST['password']));
   $url = mysqli_real_escape_string($mysqli,urldecode($_POST['url']));

   $headers = getallheaders();

   $host = gethostbyaddr($_SERVER['REMOTE_ADDR']);
   $objectid = mysqli_real_escape_string($mysqli,$headers['X-SecondLife-Object-Key']);
   $owner = mysqli_real_escape_string($mysqli,$headers['X-SecondLife-Owner-Name']); 
   $ownerid = mysqli_real_escape_string($mysqli,$headers['X-SecondLife-Owner-Key']);
   $pos = mysqli_real_escape_string($mysqli,$headers['X-SecondLife-Local-Position']);
   $region = mysqli_real_escape_string($mysqli,$headers['X-SecondLife-Region']);
   $useragent = mysqli_real_escape_string($mysqli,$_SERVER['HTTP_USER_AGENT']);

   $query = "SELECT * FROM `objdns` WHERE `domain` = '" . $domain . "'";

   $result = $mysqli->query($query);

   if (!$result) {
      echo "MYSQL ERROR";
      die();
   }

   $row = $result->fetch_assoc();

   if ($_GET['action'] == "urlupdate" && $row['password'] == sha1($password . $SALT)) {
      $objectid = mysqli_real_escape_string($mysqli,$headers['X-SecondLife-Object-Key']);

      $query = "UPDATE `objdns` SET `url`='" . $url . "' WHERE `domain` = '" . $domain . "';\n";
      $query .= "INSERT INTO `objdns_updates` (`owner`, `ownerid`, `objectid`, `region`, `pos`, `host`, `domain`, `url`, `useragent`) VALUES ('" . $owner . "', '" . $ownerid . "', '" . $objectid . "', '" . $region . "', '" . $pos . "', '" . $host . "', '" . $domain . "', '" . $url . "', '" . $useragent ."');";

      $result = $mysqli->multi_query($query);

      if (!$result) {
         echo "MYSQL ERROR";
         die();
      }
      else {
         echo "OK";
      }
   }
   else if ($_GET['action'] == "geturl") {
      $query = "INSERT INTO `objdns_queries` (`owner`, `ownerid`, `objectid`, `region`, `pos`, `host`, `domain`, `useragent`) VALUES ('" . $owner . "', '" . $ownerid . "', '" . $objectid . "', '" . $region . "', '" . $pos . "', '" . $host . "', '" . $domain . "', '" . $useragent ."');";
      $mysqli->query($query);

      echo $row['url'];
   }
   else if (!$result->num_rows) {
      echo "NO RECORD";
   }
   else {
      echo "BAD PASSWORD";
   }

   mysqli_close($mysqli);
?>
