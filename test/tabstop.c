// vi:set ts=8 sts=4 sw=4:

    static void
op_colon(oap)
    oparg_T	*oap;
{
    stuffcharReadbuff(':');
#ifdef FEAT_VISUAL
    if (oap->is_VIsual)
	stuffReadbuff((char_u *)"'<,'>");
    else
#endif
    {
	/*
	 * Make the range look nice, so it can be repeated.
	 */
	if (oap->start.lnum == curwin->w_cursor.lnum)
	    stuffcharReadbuff('.');
	else
	    stuffnumReadbuff((long)oap->start.lnum);
	if (oap->end.lnum != oap->start.lnum)
	{
	    stuffcharReadbuff(',');
	    if (oap->end.lnum == curwin->w_cursor.lnum)
		stuffcharReadbuff('.');
	    else if (oap->end.lnum == curbuf->b_ml.ml_line_count)
		stuffcharReadbuff('$');
	    else if (oap->start.lnum == curwin->w_cursor.lnum)
	    {
		stuffReadbuff((char_u *)".+");
		stuffnumReadbuff((long)oap->line_count - 1);
	    }
	    else
		stuffnumReadbuff((long)oap->end.lnum);
	}
    }
    if (oap->op_type != OP_COLON)
	stuffReadbuff((char_u *)"!");
    if (oap->op_type == OP_INDENT)
    {
#ifndef FEAT_CINDENT
	if (*get_equalprg() == NUL)
	    stuffReadbuff((char_u *)"indent");
	else
#endif
	    stuffReadbuff(get_equalprg());
	stuffReadbuff((char_u *)"\n");
    }
    else if (oap->op_type == OP_FORMAT)
    {
	if (*p_fp == NUL)
	    stuffReadbuff((char_u *)"fmt");
	else
	    stuffReadbuff(p_fp);
	stuffReadbuff((char_u *)"\n']");
    }

    /*
     * do_cmdline() does the rest
     */
}
