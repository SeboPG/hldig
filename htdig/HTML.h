//
// HTML.h
//
// $Id: HTML.h,v 1.4 1998/08/11 08:58:28 ghutchis Exp $
//
// $Log: HTML.h,v $
// Revision 1.4  1998/08/11 08:58:28  ghutchis
// Second patch for META description tags. New field in DocDB for the
// desc., space in word DB w/ proper factor.
//
// Revision 1.3  1998/08/04 15:39:28  ghutchis
//
// Added support for META robots tags.
//
// Revision 1.2  1998/07/09 09:32:04  ghutchis
//
//
// Added support for META name=description tags. Uses new config-file
// option "use_meta_description" which is off by default.
//
// Revision 1.1.1.1  1997/02/03 17:11:06  turtle
// Initial CVS
//
//
#ifndef _HTML_h_
#define _HTML_h_

#include "Parsable.h"

class Retriever;
class URL;


class HTML : public Parsable
{
public:
    //
    // Construction/Destruction
    //
                        HTML();
    virtual		~HTML();

    //
    // Main parser interface.
    //
    virtual void	parse(Retriever &retriever, URL &baseURL);

private:
    //
    // Our state variables
    //
    String		word;
    URL			*href;
    String		title;
    String		description;
    String		head;
    String		meta_dsc;
    String		tag;
    int			in_title;
    int			in_ref;
    int			in_heading;
    int			doindex;
    int                 dofollow;
    int			minimumWordLength;
    URL			*base;
    
    //
    // Helper functions
    //
    void		do_tag(Retriever &, String &);
};

#endif


