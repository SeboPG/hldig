///////////////////////////////////////////////////////////////
//
// File: HtCookieInFileJar.h - Declaration of class 'HtCookieInFileJar'
// 
// Author: Gabriele Bartolini <angusgb@users.sf.net>
// Started: Mon Jan 27 14:38:42 CET 2003
//
// Class which allows a cookie file to be imported in memory
// for ht://Check and ht://Dig applications.
//
// The cookie file format is a text file, as proposed by Netscape,
// and each line contains a name-value pair for a cookie.
// Fields within a single line are separated by the 'tab' character;
// Here is the format for a line, as taken from http://www.cookiecentral.com/faq/#3.5:
// 
// domain - The domain that created AND that can read the variable.
// flag - A TRUE/FALSE value indicating if all machines within a given domain
//	can access the variable. This value is set automatically by the browser,
//	depending on the value you set for domain.
// path - The path within the domain that the variable is valid for.
// secure - A TRUE/FALSE value indicating if a secure connection with the
//	domain is needed to access the variable.
// expiration - The UNIX time that the variable will expire on. UNIX time is
//	defined as the number of seconds since Jan 1, 1970 00:00:00 GMT.
// name - The name of the variable.
// value - The value of the variable.
//
///////////////////////////////////////////////////////////////
//
// Part of the ht://Check <http://htcheck.sourceforge.net/>
// Part of the ht://Dig package   <http://www.htdig.org/>
// Copyright (c) 1999-2003 Comune di Prato, Italia
// Copyright (c) 1995-2003 The ht://Dig Group
//
///////////////////////////////////////////////////////////////
// $Id: HtCookieInFileJar.h,v 1.1 2003/01/28 11:12:44 angusgb Exp $
///////////////////////////////////////////////////////////////

#ifndef __HtCookieInFileJar_H
#define __HtCookieInFileJar_H

#include "HtCookieMemJar.h"
#include "htString.h"

class HtCookieInFileJar: public HtCookieMemJar
{

// Public Interface
public:

	// Default constructor
	HtCookieInFileJar(const String& fn, int& result);

	// Copy constructor
	HtCookieInFileJar(const HtCookieInFileJar& rhs);

	// Destructor
	~HtCookieInFileJar();

	// Assignment operator
	HtCookieInFileJar& operator=(const HtCookieInFileJar& rhs);

	// Show stats
	virtual ostream &ShowSummary (ostream &out = std::cout);

// Protected attributes
protected:
	String _filename;	// Filename

	int Load();	// Load the contents of a cookies file into memory
};

#endif

///////////////////////////////////////////////////////////////
