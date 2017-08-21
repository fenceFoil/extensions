Version 1/170816 of Gender Speedup by Nathanael Nerode begins here.

"When using Gender Options, clean up some I6 internals with functions related to gender which are irrelevant to English or rendered obsolete with Gender Options.  Since these are called in the depths of ListWriter this should slightly improve speed.  Not included in Gender Options due to likely interference with other extensions.  Requires Gender Options.  Probably will not work with non-English languages.  Tested with Inform 6M62."

Include Gender Options by Nathanael Nerode.

Section - Replace GetGNAOfObject

[ This section of Parser.i6t contained two routines: GetGender and GetGNAOfObject.

GetGender was already dead code in the Standard Rules and is deleted.

After Gender Options has done its work, GetGNAOfObject is used in four places:

Parser.i6t uses GetGNAOfObject as the final 1-point disambiguator.  This still does check gender, though it's not very important whether it matches.

Printing.i6t uses GetGNAOfObject and then applies LanguageGNAsToArticles, which strips the gender and animate status out, to get articles.  This may be relevant for non-English languages.

ListWriter.i6t uses GetGNAOfObject % 3 to set prior_named_list_gender (in two places), which is dead code (intended for non-English langauges).

ListWriter.i6t uses (GetGNAOfObject % 6 ) / 3 in PNToVP, which is called by the autogenerated verb conjugation code. Again, it's only checking plurals.

We include complete replacements for all of these below, for maximum speed (since Inform 6 doesn't inline functions).  However, the edits to these four are quite invasive, requiring replacements of huge amounts of code just to replace one line -- so they may interfere with other extensions which want to replace the same code.

So we allow people to disable these additional edits by replacing the relevant Sections.  If they do so, we need a backup implementation of GetGNAOfObject.  We provide one which only gives plural information, for speed.
]

Include (-

! ==== ==== ==== ==== ==== ==== ==== ==== ==== ====
! Gender Speedup replacement for Parser.i6t: Gender
! ==== ==== ==== ==== ==== ==== ==== ==== ==== ====
! Determine whether to print plural name for an object.

[ GetGNAOfObject obj;
	! New protocol: return 5 if we should use plural conjugations and declensions, 2 if we should use singular conjugations and declensions.
	! If anyone's using the old protocol, this will be read as "neuter animate", which is the best default.
	if (obj has pluralname) return 5;
	else return 2;
];

-) instead of "Gender" in "Parser.i6t".

Section - Patch ScoreMatchL

Include (-

! ==== ==== ==== ==== ==== ==== ==== ==== ==== ====
! Gender Speedup replacement for Parser.i6t: ScoreMatchL
! ==== ==== ==== ==== ==== ==== ==== ==== ==== ====

! We make only one change in this entire procedure, replacing
! PowersOfTwo_TB-->(GetGNAOfObject(obj)) with GetGNABitfield

Constant SCORE__CHOOSEOBJ = 1000;
Constant SCORE__IFGOOD = 500;
Constant SCORE__UNCONCEALED = 100;
Constant SCORE__BESTLOC = 60;
Constant SCORE__NEXTBESTLOC = 40;
Constant SCORE__NOTCOMPASS = 20;
Constant SCORE__NOTSCENERY = 10;
Constant SCORE__NOTACTOR = 5;
Constant SCORE__GNA = 1;
Constant SCORE__DIVISOR = 20;

Constant PREFER_HELD;
[ ScoreMatchL context its_owner its_score obj i j threshold met a_s l_s;
!   if (indef_type & OTHER_BIT ~= 0) threshold++;
    if (indef_type & MY_BIT ~= 0)    threshold++;
    if (indef_type & THAT_BIT ~= 0)  threshold++;
    if (indef_type & LIT_BIT ~= 0)   threshold++;
    if (indef_type & UNLIT_BIT ~= 0) threshold++;
    if (indef_owner ~= nothing)      threshold++;

    #Ifdef DEBUG;
    if (parser_trace >= 4) print "   Scoring match list: indef mode ", indef_mode, " type ",
      indef_type, ", satisfying ", threshold, " requirements:^";
    #Endif; ! DEBUG

    #ifdef PREFER_HELD;
    a_s = SCORE__BESTLOC; l_s = SCORE__NEXTBESTLOC;
    if (action_to_be == ##Take or ##Remove) {
        a_s = SCORE__NEXTBESTLOC; l_s = SCORE__BESTLOC;
    }
    context = context;  ! silence warning
    #ifnot;
    a_s = SCORE__NEXTBESTLOC; l_s = SCORE__BESTLOC;
    if (context == HELD_TOKEN or MULTIHELD_TOKEN or MULTIEXCEPT_TOKEN) {
        a_s = SCORE__BESTLOC; l_s = SCORE__NEXTBESTLOC;
    }
    #endif; ! PREFER_HELD

    for (i=0 : i<number_matched : i++) {
        obj = match_list-->i; its_owner = parent(obj); its_score=0; met=0;

        !      if (indef_type & OTHER_BIT ~= 0
        !          &&  obj ~= itobj or himobj or herobj) met++;
        if (indef_type & MY_BIT ~= 0 && its_owner == actor) met++;
        if (indef_type & THAT_BIT ~= 0 && its_owner == actors_location) met++;
        if (indef_type & LIT_BIT ~= 0 && obj has light) met++;
        if (indef_type & UNLIT_BIT ~= 0 && obj hasnt light) met++;
        if (indef_owner ~= 0 && its_owner == indef_owner) met++;

        if (met < threshold) {
            #Ifdef DEBUG;
            if (parser_trace >= 4)
            	print "   ", (The) match_list-->i, " (", match_list-->i, ") in ",
            	    (the) its_owner, " is rejected (doesn't match descriptors)^";
            #Endif; ! DEBUG
            match_list-->i = -1;
        }
        else {
            its_score = 0;
            if (obj hasnt concealed) its_score = SCORE__UNCONCEALED;

            if (its_owner == actor) its_score = its_score + a_s;
            else
                if (its_owner == actors_location) its_score = its_score + l_s;
                else
                    if (its_owner ~= compass) its_score = its_score + SCORE__NOTCOMPASS;

            its_score = its_score + SCORE__CHOOSEOBJ * ChooseObjects(obj, 2);

            if (obj hasnt scenery) its_score = its_score + SCORE__NOTSCENERY;
            if (obj ~= actor) its_score = its_score + SCORE__NOTACTOR;

            !   A small bonus for having a matching GNA,
            !   for sorting out ambiguous articles and the like.
			!   Patched by Gender Speedup by Nathanael Nerode.

            if (indef_cases & GetGNABitfield(obj) )
                its_score = its_score + SCORE__GNA;

            match_scores-->i = match_scores-->i + its_score;
            #Ifdef DEBUG;
            if (parser_trace >= 4) print "     ", (The) match_list-->i, " (", match_list-->i,
              ") in ", (the) its_owner, " : ", match_scores-->i, " points^";
            #Endif; ! DEBUG
        }
     }

    for (i=0 : i<number_matched : i++) {
        while (match_list-->i == -1) {
            if (i == number_matched-1) { number_matched--; break; }
            for (j=i : j<number_matched-1 : j++) {
                match_list-->j = match_list-->(j+1);
                match_scores-->j = match_scores-->(j+1);
            }
            number_matched--;
        }
    }
];


-) instead of "ScoreMatchL" in "Parser.i6t".

Section - Patch PrefaceByArticle

Include (-
! ==== ==== ==== ==== ==== ==== ==== ==== ==== ====
! Gender Speedup replacement for Printing.i6t: Object Names II
! ==== ==== ==== ==== ==== ==== ==== ==== ==== ====

! We make only one small change: we remove the bit twiddling code which used GetGNAOfObject.

Global short_name_case;

[ PrefaceByArticle obj acode pluralise capitalise  i artform findout artval;
    if (obj provides articles) {
        artval=(obj.&articles)-->(acode+short_name_case*LanguageCases);
        if (capitalise)
            print (Cap) artval, " ";
        else
            print (string) artval, " ";
        if (pluralise) return;
        print (PSN__) obj; return;
    }

    ! Gender Speedup: This is the ultra-fast English-only way of checking for plurals.
    i = pluralise || (obj has pluralname);
    
    artform = LanguageArticles
        + 3*WORDSIZE*LanguageContractionForms*(short_name_case + i*LanguageCases);

    #Iftrue (LanguageContractionForms == 2);
    if (artform-->acode ~= artform-->(acode+3)) findout = true;
    #Endif; ! LanguageContractionForms
    #Iftrue (LanguageContractionForms == 3);
    if (artform-->acode ~= artform-->(acode+3)) findout = true;
    if (artform-->(acode+3) ~= artform-->(acode+6)) findout = true;
    #Endif; ! LanguageContractionForms
    #Iftrue (LanguageContractionForms == 4);
    if (artform-->acode ~= artform-->(acode+3)) findout = true;
    if (artform-->(acode+3) ~= artform-->(acode+6)) findout = true;
    if (artform-->(acode+6) ~= artform-->(acode+9)) findout = true;
    #Endif; ! LanguageContractionForms
    #Iftrue (LanguageContractionForms > 4);
    findout = true;
    #Endif; ! LanguageContractionForms

    #Ifdef TARGET_ZCODE;
    if (standard_interpreter ~= 0 && findout) {
        StorageForShortName-->0 = 160;
        @output_stream 3 StorageForShortName;
        if (pluralise) print (number) pluralise; else print (PSN__) obj;
        @output_stream -3;
        acode = acode + 3*LanguageContraction(StorageForShortName + 2);
    }
    #Ifnot; ! TARGET_GLULX
    if (findout) {
        if (pluralise)
            Glulx_PrintAnyToArray(StorageForShortName, 160, EnglishNumber, pluralise);
        else
            Glulx_PrintAnyToArray(StorageForShortName, 160, PSN__, obj);
        acode = acode + 3*LanguageContraction(StorageForShortName);
    }
    #Endif; ! TARGET_

    Cap (artform-->acode, ~~capitalise); ! print article
    if (pluralise) return;
    print (PSN__) obj;
];

-) instead of "Object Names II" in "Printing.i6t".

Section - Patch PNToVP and RegardingMarkedObjects

Include (-
! ==== ==== ==== ==== ==== ==== ==== ==== ==== ====
! Gender Speedup replacement for ListWriter.i6t: List Number and Gender
! ==== ==== ==== ==== ==== ==== ==== ==== ==== ====

! Adds expresss implementation of RegardingMarkedObjects, eliminating costly features not used in English.
! Stops tracking prior_named_list_gender, which is dead code in English.
! Fast plural detection in PNToVP.

! Express implementation of "regarding marked objects" for English only.
! Don't track prior_named_list_gender, which is dead code in English.
! prior_named_list is only ever checked for >=2 in English, so stop counting at 2; avoids most of an entire object loop.

[ RegardingMarkedObjects
	obj;
	prior_named_list = 0;
	prior_named_noun = nothing;
	objectloop (obj ofclass Object && obj has workflag2) {
		prior_named_list++;
		if (prior_named_list == 1) {
			! Prior named noun is the *first* object in the list.
			prior_named_noun = obj;
		}
		if (prior_named_list == 2) break; ! This is all we need to know in English.
	}
	return;	
];

! Strip prior_named_list_gender tracking
[ RegardingSingleObject obj;
	prior_named_list = 1;
	prior_named_noun = obj;
];

! Strip prior_named_list_gender tracking
[ RegardingNumber n;
	prior_named_list = n;
	prior_named_noun = nothing;
];

! Much simplified plural checking
[ PNToVP gna;
	if (prior_named_noun == player) return story_viewpoint;
	if ( (prior_named_list >= 2) || (prior_named_noun && (prior_named_noun has pluralname) ) ) return 6;
	return 3;
];

[ PrintVerbAsValue vb;
	if (vb == 0) print "(no verb)";
	else { print "verb "; vb(1); }
];

[ VerbIsMeaningful vb;
	if ((vb) && (BlkValueCompare(vb(CV_MEANING), Rel_Record_0) ~= 0)) rtrue;
	rfalse;
];

[ VerbIsModal vb;
	if ((vb) && (vb(CV_MODAL))) rtrue;
	rfalse;
];

-) instead of "List Number and Gender" in "ListWriter.i6t".

Section - Patch WriteListOfMarkedObjects

Include (-
! ==== ==== ==== ==== ==== ==== ==== ==== ==== ====
! Gender Speedup replacement for ListWriter.i6t: WriteListOfMarkedObjects
! ==== ==== ==== ==== ==== ==== ==== ==== ==== ====
Global MarkedObjectArray = 0;
Global MarkedObjectLength = 0;

! Gender Speedup: remove calculation of prior_named_list_gender, which is dead code in English.

[ WriteListOfMarkedObjects style
	obj common_parent first mixed_parentage length;

	objectloop (obj ofclass Object && obj has workflag2) {
		length++;
		if (first == nothing) { first = obj; common_parent = parent(obj); }
		else { if (parent(obj) ~= common_parent) mixed_parentage = true; }
	}
	if (mixed_parentage) common_parent = nothing;

	if (length == 0) {
    	if (style & ISARE_BIT ~= 0) LIST_WRITER_INTERNAL_RM('W');
    	else if (style & CFIRSTART_BIT ~= 0) LIST_WRITER_INTERNAL_RM('X');
		else LIST_WRITER_INTERNAL_RM('Y');
	} else {
		@push MarkedObjectArray; @push MarkedObjectLength;
		MarkedObjectArray = RequisitionStack(length);
		MarkedObjectLength = length;
		if (MarkedObjectArray == 0) return RunTimeProblem(RTP_LISTWRITERMEMORY); 

		if (common_parent) {
			ObjectTreeCoalesce(child(common_parent));
			length = 0;
			objectloop (obj in common_parent) ! object tree order
				if (obj has workflag2) MarkedObjectArray-->length++ = obj;
		} else {
			length = 0;
			objectloop (obj ofclass Object) ! object number order
				if (obj has workflag2) MarkedObjectArray-->length++ = obj;
		}

		WriteListFrom(first, style, 0, false, MarkedListIterator);

		FreeStack(MarkedObjectArray);
		@pull MarkedObjectLength; @pull MarkedObjectArray;
	}
	prior_named_list = length;
	return;
];

-) instead of "WriteListOfMarkedObjects" in "ListWriter.i6t".

Gender Speedup ends here.

---- DOCUMENTATION ----

If you're using the English language, there's a lot of unnecessary gender tracking code in the Inform 6 templates layer, which is used for French, German, etc.  This includes heavily used loops when listing objects.  My extension Gender Options replaces a substantial amount of the gender tracking code.  Since the Inform 6 compiler doesn't do any optimization, it's worth doing it ourselves.  This gets rid of the rest of the dead and irrelevant gender tracking code for a small speedup.

It is strongly recommended to tell the I6 compiler to strip out unused subroutines to shrink the story file size.
	Use OMIT_UNUSED_ROUTINES of 1.

This requires rather invasive replacements of large sections of I6 template code just to change one or two lines.  This may interfere with other extensions which patch the I6 code.  If this happens, each section can be individually disabled, as follows:

	Section - Disabled 1 (in place of Section - Patch ScoreMatchL in Gender Speedup by Nathanael Nerode)
	Section - Disabled 2 (in place of Section - Patch PrefaceByArticle in Gender Speedup by Nathanael Nerode)
	Section - Disabled 3 (in place of Section - Patch PNToVP and RegardingMarkedObjects in Gender Speedup by Nathanael Nerode)
	Section - Disabled 4 (in place of Section - Patch WriteListOfMarkedObjects in Gender Speedup by Nathanael Nerode)

One section exists solely to support other extensions which are patching the other sections, so you shouldn't replace it, but if you need to:
	Section - Disabled 7 (in place of Section - Replace GetGNAOfObject in Gender Speedup by Nathanael Nerode)
