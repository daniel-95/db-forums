-- MySQL dump 10.13  Distrib 5.5.43, for debian-linux-gnu (i686)
--
-- Host: localhost    Database: db_forums
-- ------------------------------------------------------
-- Server version	5.5.43-0ubuntu0.14.04.1

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `follow`
--

DROP TABLE IF EXISTS `follow`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `follow` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `follower` varchar(255) DEFAULT NULL,
  `followee` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `follower_ee` (`follower`,`followee`),
  UNIQUE KEY `unique_pair` (`follower`,`followee`),
  KEY `followee_FK` (`followee`),
  CONSTRAINT `followee_FK` FOREIGN KEY (`followee`) REFERENCES `user` (`email`),
  CONSTRAINT `follower_FK` FOREIGN KEY (`follower`) REFERENCES `user` (`email`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `forum`
--

DROP TABLE IF EXISTS `forum`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `forum` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `user_id` int(10) unsigned NOT NULL,
  `short_name` varchar(128) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`),
  UNIQUE KEY `short_name` (`short_name`),
  KEY `user_id` (`user_id`),
  CONSTRAINT `forum_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `user` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `post`
--

DROP TABLE IF EXISTS `post`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `post` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `message` text NOT NULL,
  `date` datetime NOT NULL,
  `thread_id` int(10) unsigned NOT NULL,
  `user` varchar(255) NOT NULL,
  `parent_id` int(10) unsigned DEFAULT NULL,
  `is_approved` tinyint(1) NOT NULL DEFAULT '0',
  `is_deleted` tinyint(1) NOT NULL DEFAULT '0',
  `is_edited` tinyint(1) NOT NULL DEFAULT '0',
  `is_spam` tinyint(1) NOT NULL DEFAULT '0',
  `is_highlighted` tinyint(1) NOT NULL DEFAULT '0',
  `forum` varchar(128) NOT NULL,
  `likes` int(10) unsigned NOT NULL DEFAULT '0',
  `dislikes` int(10) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `thread_date` (`thread_id`,`date`),
  UNIQUE KEY `user_date` (`user`,`date`),
  KEY `parent_id` (`parent_id`),
  KEY `forum` (`forum`),
  CONSTRAINT `post_ibfk_1` FOREIGN KEY (`thread_id`) REFERENCES `thread` (`id`),
  CONSTRAINT `post_ibfk_2` FOREIGN KEY (`parent_id`) REFERENCES `post` (`id`),
  CONSTRAINT `post_ibfk_3` FOREIGN KEY (`user`) REFERENCES `user` (`email`),
  CONSTRAINT `post_ibfk_4` FOREIGN KEY (`forum`) REFERENCES `forum` (`short_name`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `subscription`
--

DROP TABLE IF EXISTS `subscription`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `subscription` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `user` varchar(255) DEFAULT NULL,
  `thread_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `user_thread` (`user`,`thread_id`),
  KEY `subscription_thread_id` (`thread_id`),
  CONSTRAINT `subscription_ibfk_1` FOREIGN KEY (`user`) REFERENCES `user` (`email`),
  CONSTRAINT `subscription_thread_id` FOREIGN KEY (`thread_id`) REFERENCES `thread` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `thread`
--

DROP TABLE IF EXISTS `thread`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `thread` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `title` varchar(128) NOT NULL,
  `date` datetime NOT NULL,
  `message` text NOT NULL,
  `forum` varchar(255) DEFAULT NULL,
  `user` varchar(255) DEFAULT NULL,
  `is_deleted` tinyint(1) NOT NULL DEFAULT '0',
  `is_closed` tinyint(1) NOT NULL DEFAULT '0',
  `slug` varchar(64) NOT NULL,
  `likes` smallint(5) unsigned NOT NULL DEFAULT '0',
  `dislikes` smallint(5) unsigned NOT NULL DEFAULT '0',
  `posts` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `title` (`title`),
  KEY `forum_id` (`forum`),
  KEY `user_id` (`user`),
  CONSTRAINT `fk_forum_short` FOREIGN KEY (`forum`) REFERENCES `forum` (`short_name`),
  CONSTRAINT `fk_name` FOREIGN KEY (`user`) REFERENCES `user` (`email`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `user`
--

DROP TABLE IF EXISTS `user`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `user` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `username` varchar(255) NOT NULL,
  `email` varchar(255) NOT NULL,
  `isAnonymous` tinyint(1) unsigned DEFAULT '0',
  `about` text,
  `name` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `email` (`email`)
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2015-05-04 17:15:26
