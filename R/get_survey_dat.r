#' Download a labeled survey data set
#'
#' Download a survey data set from Qualtrics corresponding to a variable
#' dictionary generated by \code{\link[qualtdict]{dict_generate}}.
#' Question, item texts and level labels are added as attributes.
#'
#' @param dict A variable dictionary returned by
#' \code{\link[qualtdict]{dict_generate}}.
#' @param surveyID String. A variable dictionary returned by
#' \code{\link[qualtdict]{dict_generate}} has the survey ID as an
#' attribute. If it is read from elsewhere, this needs to be specified
#' manually. Defaults to \code{NULL}.
#' @param keys A character vector containing variables to be added, if
#' \code{split_by_block} is \code{TRUE}, to all individual block data sets.
#' Can also be used to add variables (e.g. IP address) found on Qualtrics
#' but not in the dictionary to the downloaded data sets.
#' @param skip_mistakes Logical. If \code{TRUE}, variables with potenetial
#' level-label mistakes will be removed from the data set.
#' @param split_by_block Logical. If \code{TRUE}, the function returns a
#' list with each element being the data set for a single survey block.
#' @param ... Other arguments passed to
#' \code{\link[qualtRics]{fetch_survey}}. Note that \code{surveyID},
#' \code{import_id}, \code{convert}, \code{label} and \code{include_qids}
#' will be overwritten by the function.
#'
#' @export
#' @examples
#' \dontrun{
#'
#' # Generate a dictionary
#' mydict <- dict_generate("SV_4YyAHbAxpdbzacl",
#'   survey_name = "mysurvey",
#'   var_name = "easy_name",
#'   block_pattern = block_pattern,
#'   block_sep = ".",
#'   split_by_block = FALSE
#' )
#' survey_dat <- get_survey_data(mydict,
#'   unanswer_recode = -77,
#'   unanswer_recode_multi = 0
#' )
#' }
get_survey_data <- function(dict,
                            surveyID = NULL,
                            keys = NULL,
                            split_by_block = FALSE,
                            skip_mistakes = FALSE,
                            ...) {

  # Validate the dictionary
  suppressWarnings(error_list <- dict_validate(dict)$error)
  if (!is.null(error_list$non_unique_names)) {
    message("Variables don't have unique names.")
    return(error_list$non_unique_names)
  }

  mistake_qids <- unique(error_list$mistake_dict[["qid"]])

  args <- list(...)
  args$force_request <- TRUE
  args$surveyID <- attr(dict, "surveyID")
  args$import_id <- TRUE
  args$convert <- FALSE
  args$label <- FALSE
  # What about loop and merge?
  include_qids <- unique(str_extract(dict[["qid"]], "QID[0-9]+"))
  # Somehow doesn't work when there is only one question
  if (length(include_qids) > 1) {
    args$include_questions <- include_qids
  }

  survey <- do.call(fetch_survey, args)

  # Not sure why underscore is appended sometimes when include_questions is specified
  colnames(survey) <- str_remove(colnames(survey), "_$")

  if (!is.null(mistake_qids) & !skip_mistakes) {
    warning("There are variables with potential incorrect level-label codings.
            Run 'dict_validate()' on the dictionary object for details or
            specify 'skip_mistakes = TRUE' to not apply recoding to
            variables with mistakes.")
  }

  if (skip_mistakes) {
    survey <- filter(survey, !qid %in% skip_qids)
  }

  if (split_by_block == TRUE) {
    keys <- unique(unlist(dict[dict[["name"]] %in% keys, "qid"]))
    keys_dat <- dict[dict[["name"]] %in% keys, ]

    block_dict <- map(
      split(dict, dict$block),
      ~ bind_rows(
        keys_dat[-match(keys_dat[["name"]], .x[["name"]])],
        .x
      ) %>%
        select(keys, everything())
    )

    return(map(block_dict, survey_recode,
      dat = survey,
      keys = keys,
      unanswer_recode = args$unanswer_recode,
      unanswer_recode_multi = args$unanswer_recode_multi
    ))
  } else {
    return(survey_recode(dict,
      dat = survey, keys = keys,
      unanswer_recode = args$unanswer_recode,
      unanswer_recode_multi = args$unanswer_recode_multi,
      numeric_to_pos = numeric_to_pos
    ))
  }
}

survey_recode <- function(dict, dat, keys, unanswer_recode, unanswer_recode_multi, numeric_to_pos) {
  in_dat <- dict[["qid"]] %in% colnames(dat)
  dict <- dict[in_dat, ]
  unique_qids <- unique(dict[["qid"]])
  unique_varnames <- unique(dict[["name"]])

  keys <- c("externalDataReference", "startDate", "endDate", keys)
  dat_cols <- c(keys, unique_qids)
  varnames <- setNames(unique_qids, unique_varnames)
  dat <- rename(dat[dat_cols], !!!varnames)

  # level = unique to preserve ordering
  split_dict <- split(dict, factor(dict$qid, level = unique(dict$qid)))
  dat_vars <- map2_df(
    dat[unique_varnames], split_dict,
    ~ survey_var_recode(.x, .y,
      unanswer_recode = unanswer_recode,
      unanswer_recode_multi = unanswer_recode_multi
    )
  )

  bind_cols(dat[keys], dat_vars)
}

survey_var_recode <- function(var, var_dict, unanswer_recode, unanswer_recode_multi, numeric_to_pos) {
  type <- var_dict[["type"]][1]
  selector <- var_dict[["selector"]][1]
  levels <- var_dict[["level"]]
  labels <- var_dict[["label"]]

  if (type == "TE" || any(grepl("_TEXT", levels))) {}
  else if (selector == "MACOL" || selector == "MAVR" || selector == "MAHR") {
    levels <- 1
    if (!is.null(unanswer_recode_multi)) {
      levels <- c(levels, unanswer_recode_multi)
      labels <- c(labels, paste("Not", labels))
    }
  }

  # If multiple rows it's ordinal
  else if (nrow(var_dict) > 1) {
    labels <- grep("TEXT", labels, invert = T, value = T)
    levels <- grep("TEXT", levels, invert = T, value = T)
    if (!is.null(unanswer_recode)) {
      levels <- c(levels, unanswer_recode)
      labels <- c(labels, "Seen but not answered")
    }
  }

  var <- set_labels(var, labels = setNames(levels, labels))
  text_label <- unique(paste_narm(var_dict[["question"]], var_dict[["item"]]))
  var <- set_label(var, label = text_label)

  return(var)
}