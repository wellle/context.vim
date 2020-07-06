    static char_u *
list_arg_vars(eap, arg, first)
    exarg_T     *eap;
    char_u      *arg;
    int         *first;
{
    int         error = FALSE;
    int         len;
    char_u      *name;
    char_u      *name_start;
    char_u      *arg_subsc;
    char_u      *tofree;
    typval_T    tv;

    while (!ends_excmd(*arg) && !got_int)
    {
        if (error || eap->skip)
        {
            arg = find_name_end(arg, NULL, NULL, FNE_INCL_BR | FNE_CHECK_START);
            if (!vim_iswhite(*arg) && !ends_excmd(*arg))
            {
                emsg_severe = TRUE;
                EMSG(_(e_trailing));
                break;
            }
        }
        else
        {
            /* get_name_len() takes care of expanding curly braces */
            name_start = name = arg;
            len = get_name_len(&arg, &tofree, TRUE, TRUE);
            if (len <= 0)
            {
                /* This is mainly to keep test 49 working: when expanding
                 * curly braces fails overrule the exception error message. */
                if (len < 0 && !aborting())
                {
                    emsg_severe = TRUE;
                    EMSG2(_(e_invarg2), arg);
                    break;
                }
                error = TRUE;
            }
            else
            {
                if (tofree != NULL)
                    name = tofree;
                if (get_var_tv(name, len, &tv, TRUE) == FAIL)
                    error = TRUE;
                else
                {
                    /* handle d.key, l[idx], f(expr) */
                    arg_subsc = arg;
                    if (handle_subscript(&arg, &tv, TRUE, TRUE) == FAIL)
                        error = TRUE;
                    else
                    {
                        if (arg == arg_subsc && len == 2 && name[1] == ':')
                        {
                            switch (*name)
                            {
                                case 'g': list_glob_vars(first); break;
                                case 'b': list_buf_vars(first); break;
                                case 'w': list_win_vars(first); break;
#ifdef FEAT_WINDOWS
                                case 't': list_tab_vars(first); break;
#endif
                                case 'v': list_vim_vars(first); break;
                                case 's': list_script_vars(first); break;
                                case 'l': list_func_vars(first); break;
                                default:
                                          while (!ends_excmd(*arg) && !got_int)
                                          {
                                              if (error || eap->skip)
                                              {
                                                  arg = find_name_end(arg, NULL, NULL, FNE_INCL_BR | FNE_CHECK_START);
                                                  if (!vim_iswhite(*arg) && !ends_excmd(*arg))
                                                  {
                                                      emsg_severe = TRUE;
                                                      EMSG(_(e_trailing));
                                                      break;
                                                  }
                                              }
                                              else
                                              {
                                                  /* get_name_len() takes care of expanding curly braces */
                                                  name_start = name = arg;
                                                  len = get_name_len(&arg, &tofree, TRUE, TRUE);
                                                  if (len <= 0)
                                                  {
                                                      /* This is mainly to keep test 49 working: when expanding
                                                       * curly braces fails overrule the exception error message. */
                                                      if (len < 0 && !aborting())
                                                      {
                                                          emsg_severe = TRUE;
                                                          EMSG2(_(e_invarg2), arg);
                                                          break;
                                                      }
                                                      error = TRUE;
                                                  }
                                                  else
                                                  {
                                                      if (tofree != NULL)
                                                          name = tofree;
                                                      if (get_var_tv(name, len, &tv, TRUE) == FAIL)
                                                          error = TRUE;
                                                      else
                                                      {
                                                          /* handle d.key, l[idx], f(expr) */
                                                          arg_subsc = arg;
                                                          if (handle_subscript(&arg, &tv, TRUE, TRUE) == FAIL)
                                                              error = TRUE;
                                                          else
                                                          {
                                                              if (arg == arg_subsc && len == 2 && name[1] == ':')
                                                              {
                                                                  switch (*name)
                                                                  {
                                                                      case 'g': list_glob_vars(first); break;
                                                                      case 'b': list_buf_vars(first); break;
                                                                      case 'w': list_win_vars(first); break;
#ifdef FEAT_WINDOWS
                                                                      case 't': list_tab_vars(first); break;
#endif
                                                                      case 'v': list_vim_vars(first); break;
                                                                      case 's': list_script_vars(first); break;
                                                                      case 'l': list_func_vars(first); break;
                                                                      default:
                                                                                EMSG2(_("E738: Can't list variables for %s"), name);
                                                                                XXX
                                                                  }
                                                              }
                                                              else
                                                              {
                                                                  char_u      numbuf[NUMBUFLEN];
                                                                  char_u      *tf;
                                                                  int         c;
                                                                  char_u      *s;

                                                                  s = echo_string(&tv, &tf, numbuf, 0);
                                                                  c = *arg;
                                                                  *arg = NUL;
                                                                  list_one_var_a((char_u *)"",
                                                                          arg == arg_subsc ? name : name_start,
                                                                          tv.v_type,
                                                                          s == NULL ? (char_u *)"" : s,
                                                                          first);
                                                                  *arg = c;
                                                                  vim_free(tf);
                                                              }
                                                              clear_tv(&tv);
                                                          }
                                                      }
                                                  }

                                                  vim_free(tofree);
                                              }

                                              arg = skipwhite(arg);
                                          }
                            }
                        }
                        else
                        {
                            char_u      numbuf[NUMBUFLEN];
                            char_u      *tf;
                            int         c;
                            char_u      *s;

                            s = echo_string(&tv, &tf, numbuf, 0);
                            c = *arg;
                            *arg = NUL;
                            list_one_var_a((char_u *)"",
                                    arg == arg_subsc ? name : name_start,
                                    tv.v_type,
                                    s == NULL ? (char_u *)"" : s,
                                    first);
                            *arg = c;
                            vim_free(tf);
                        }
                        clear_tv(&tv);
                    }
                }
            }

            vim_free(tofree);
        }

        arg = skipwhite(arg);
    }

    return arg;
}
