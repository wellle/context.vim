    static int
eval4(arg, rettv, evaluate)
    char_u      **arg;
    typval_T    *rettv;
    int         evaluate;
{
    typval_T    var2;
    char_u      *p;
    int         i;
    exptype_T   type = TYPE_UNKNOWN;
    int         type_is = FALSE;    /* TRUE for "is" and "isnot" */
    int         len = 2;
    long        n1, n2;
    char_u      *s1, *s2;
    char_u      buf1[NUMBUFLEN], buf2[NUMBUFLEN];
    regmatch_T  regmatch;
    int         ic;
    char_u      *save_cpo;

    /*
     * Get the first variable.
     */
    if (eval5(arg, rettv, evaluate) == FAIL)
        return FAIL;

    p = *arg;
    switch (p[0])
    {
        case '=':   if (p[1] == '=')
                        type = TYPE_EQUAL;
                    else if (p[1] == '~')
                        type = TYPE_MATCH;
                    break;
        case '!':   if (p[1] == '=')
                        type = TYPE_NEQUAL;
                    else if (p[1] == '~')
                        type = TYPE_NOMATCH;
                    break;
        case '>':   if (p[1] != '=')
                    {
                        type = TYPE_GREATER;
                        len = 1;
                    }
                    else
                        type = TYPE_GEQUAL;
                    break;
        case '<':   if (p[1] != '=')
                    {
                        type = TYPE_SMALLER;
                        len = 1;
                    }
                    else
                        type = TYPE_SEQUAL;
                    break;
        case 'i':   if (p[1] == 's')
                    {
                        if (p[2] == 'n' && p[3] == 'o' && p[4] == 't')
                            len = 5;
                        if (!vim_isIDc(p[len]))
                        {
                            type = len == 2 ? TYPE_EQUAL : TYPE_NEQUAL;
                            type_is = TRUE;
                        }
                    }
                    break;
    }

    /*
     * If there is a comparative operator, use it.
     */
    if (type != TYPE_UNKNOWN)
    {
        /* extra question mark appended: ignore case */
        if (p[len] == '?')
        {
            ic = TRUE;
            ++len;
        }
        /* extra '#' appended: match case */
        else if (p[len] == '#')
        {
            ic = FALSE;
            ++len;
        }
        /* nothing appended: use 'ignorecase' */
        else
            ic = p_ic;

        /*
         * Get the second variable.
         */
        *arg = skipwhite(p + len);
        if (eval5(arg, &var2, evaluate) == FAIL)
        {
            clear_tv(rettv);
            return FAIL;
        }

        if (evaluate)
        {
            if (type_is && rettv->v_type != var2.v_type)
            {
                /* For "is" a different type always means FALSE, for "notis"
                 * it means TRUE. */
                n1 = (type == TYPE_NEQUAL);
            }
            else if (rettv->v_type == VAR_LIST || var2.v_type == VAR_LIST)
            {
                if (type_is)
                {
                    n1 = (rettv->v_type == var2.v_type
                                   && rettv->vval.v_list == var2.vval.v_list);
                    if (type == TYPE_NEQUAL)
                        n1 = !n1;
                }
                else if (rettv->v_type != var2.v_type
                        || (type != TYPE_EQUAL && type != TYPE_NEQUAL))
                {
                    if (rettv->v_type != var2.v_type)
                        EMSG(_("E691: Can only compare List with List"));
                    else
                        EMSG(_("E692: Invalid operation for Lists"));
                    clear_tv(rettv);
                    clear_tv(&var2);
                    return FAIL;
                }
                else
                {
                    /* Compare two Lists for being equal or unequal. */
                    n1 = list_equal(rettv->vval.v_list, var2.vval.v_list,
                                                                   ic, FALSE);
                    if (type == TYPE_NEQUAL)
                        n1 = !n1;
                }
            }

            else if (rettv->v_type == VAR_DICT || var2.v_type == VAR_DICT)
            {
                if (type_is)
                {
                    n1 = (rettv->v_type == var2.v_type
                                   && rettv->vval.v_dict == var2.vval.v_dict);
                    if (type == TYPE_NEQUAL)
                        n1 = !n1;
                }
                else if (rettv->v_type != var2.v_type
                        || (type != TYPE_EQUAL && type != TYPE_NEQUAL))
                {
                    if (rettv->v_type != var2.v_type)
                        EMSG(_("E735: Can only compare Dictionary with Dictionary"));
                    else
                        EMSG(_("E736: Invalid operation for Dictionary"));
                    clear_tv(rettv);
                    clear_tv(&var2);
                    return FAIL;
                }
                else
                {
                    /* Compare two Dictionaries for being equal or unequal. */
                    n1 = dict_equal(rettv->vval.v_dict, var2.vval.v_dict,
                                                                   ic, FALSE);
                    if (type == TYPE_NEQUAL)
                        n1 = !n1;
                }
            }

            else if (rettv->v_type == VAR_FUNC || var2.v_type == VAR_FUNC)
            {
                if (rettv->v_type != var2.v_type
                        || (type != TYPE_EQUAL && type != TYPE_NEQUAL))
                {
                    if (rettv->v_type != var2.v_type)
                        EMSG(_("E693: Can only compare Funcref with Funcref"));
                    else
                        EMSG(_("E694: Invalid operation for Funcrefs"));
                    clear_tv(rettv);
                    clear_tv(&var2);
                    return FAIL;
                }
                else
                {
                    /* Compare two Funcrefs for being equal or unequal. */
                    if (rettv->vval.v_string == NULL
                                                || var2.vval.v_string == NULL)
                        n1 = FALSE;
                    else
                        n1 = STRCMP(rettv->vval.v_string,
                                                     var2.vval.v_string) == 0;
                    if (type == TYPE_NEQUAL)
                        n1 = !n1;
                }
            }

#ifdef FEAT_FLOAT
            /*
             * If one of the two variables is a float, compare as a float.
             * When using "=~" or "!~", always compare as string.
             */
            else if ((rettv->v_type == VAR_FLOAT || var2.v_type == VAR_FLOAT)
                    && type != TYPE_MATCH && type != TYPE_NOMATCH)
            {
                float_T f1, f2;

                if (rettv->v_type == VAR_FLOAT)
                    f1 = rettv->vval.v_float;
                else
                    f1 = get_tv_number(rettv);
                if (var2.v_type == VAR_FLOAT)
                    f2 = var2.vval.v_float;
                else
                    f2 = get_tv_number(&var2);
                n1 = FALSE;
                switch (type)
                {
                    case TYPE_EQUAL:    n1 = (f1 == f2); break;
                    case TYPE_NEQUAL:   n1 = (f1 != f2); break;
                    case TYPE_GREATER:  n1 = (f1 > f2); break;
                    case TYPE_GEQUAL:   n1 = (f1 >= f2); break;
                    case TYPE_SMALLER:  n1 = (f1 < f2); break;
                    case TYPE_SEQUAL:   n1 = (f1 <= f2); break;
                    case TYPE_UNKNOWN:
                    case TYPE_MATCH:
                    case TYPE_NOMATCH:  break;  /* avoid gcc warning */
                }
            }
#endif

            /*
             * If one of the two variables is a number, compare as a number.
             * When using "=~" or "!~", always compare as string.
             */
            else if ((rettv->v_type == VAR_NUMBER || var2.v_type == VAR_NUMBER)
                    && type != TYPE_MATCH && type != TYPE_NOMATCH)
            {
                n1 = get_tv_number(rettv);
                n2 = get_tv_number(&var2);
                switch (type)
                {
                    case TYPE_EQUAL:    n1 = (n1 == n2); break;
                    case TYPE_NEQUAL:   n1 = (n1 != n2); break;
                    case TYPE_GREATER:  n1 = (n1 > n2); break;
                    case TYPE_GEQUAL:   n1 = (n1 >= n2); break;
                    case TYPE_SMALLER:  n1 = (n1 < n2); break;
                    case TYPE_SEQUAL:   n1 = (n1 <= n2); break;
                    case TYPE_UNKNOWN:
                    case TYPE_MATCH:
                    case TYPE_NOMATCH:  break;  /* avoid gcc warning */
                }
            }
            else
            {
                s1 = get_tv_string_buf(rettv, buf1);
                s2 = get_tv_string_buf(&var2, buf2);
                if (type != TYPE_MATCH && type != TYPE_NOMATCH)
                    i = ic ? MB_STRICMP(s1, s2) : STRCMP(s1, s2);
                else
                    i = 0;
                n1 = FALSE;
                switch (type)
                {
                    case TYPE_EQUAL:    n1 = (i == 0); break;
                    case TYPE_NEQUAL:   n1 = (i != 0); break;
                    case TYPE_GREATER:  n1 = (i > 0); break;
                    case TYPE_GEQUAL:   n1 = (i >= 0); break;
                    case TYPE_SMALLER:  n1 = (i < 0); break;
                    case TYPE_SEQUAL:   n1 = (i <= 0); break;

                    case TYPE_MATCH:
                    case TYPE_NOMATCH:
                            /* avoid 'l' flag in 'cpoptions' */
                            save_cpo = p_cpo;
                            p_cpo = (char_u *)"";
                            regmatch.regprog = vim_regcomp(s2,
                                                        RE_MAGIC + RE_STRING);
                            regmatch.rm_ic = ic;
                            if (regmatch.regprog != NULL)
                            {
                                n1 = vim_regexec_nl(&regmatch, s1, (colnr_T)0);
                                vim_free(regmatch.regprog);
                                if (type == TYPE_NOMATCH)
                                    n1 = !n1;
                                    XXX
                            }
                            p_cpo = save_cpo;
                            break;

                    case TYPE_UNKNOWN:  break;  /* avoid gcc warning */
                }
            }
            clear_tv(rettv);
            clear_tv(&var2);
            rettv->v_type = VAR_NUMBER;
            rettv->vval.v_number = n1;
        }
    }

    return OK;
}
