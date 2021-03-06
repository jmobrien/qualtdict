qualtdict
=========

**License:** [MIT](https://opensource.org/licenses/MIT)

[Qualtrics](https://www.qualtrics.com/) is an online survey and data collection
software platform. The qualtdict package builds on the
[qualtRics](https://github.com/ropensci/qualtRics) R package which implements
the retrieval of survey data using the Qualtrics API. The current package makes
more comprehensive use of the survey metadata and generates a variable
dictionary inlucding most of the information essential for data processing and
analysis. It also uses a modified version of the RAKE (Rapid Automatic Keyword
Extraction; https://www.osti.gov/biblio/978967) algorithm implemented in the
package [slowraker](https://github.com/cran/slowraker) to generate meaningful
names for variables in the survey, as well as using the
[sjlabelled](https://github.com/strengejacke/sjlabelled) package to add a
comprehensive set of metadata attributes that uniquely identifies each variable.

Installation
------------

This package is in an early stage of development and can be installed with
the [devtools](https://cran.r-project.org/package=devtools) package. 

Note that the package currently depends on my own fork of the
[qualtRics](https://github.com/ropensci/qualtRics) package (the pull requests of
which I have submitted).

``` r
install.packages("devtools")
devtools::install_github("lyh970817/qualtRics", ref = "qualtdict")
devtools::install_github("lyh970817/qultdict")
```

A demo workflow
---------------

You need to first register your Qualtrics credentials with the function
`qualtrics_api_credentials` exported from the package
[qualtRics](https://www.qualtrics.com/).

``` r
library(qualtdict)

qualtrics_api_credentials(api_key = "<YOUR-QUALTRICS_API_KEY>",
                          base_url = "<YOUR-QUALTRICS_BASE_URL>",
                          install = TRUE)
```

You can then generate a variable dictionary with a Qualtrics survey ID.

``` r
mydict <- dict_generate("SV_4YyAHbAxpdbzacl", var_name = "question_name")
```

You may wish to generate meaningful variable names (if you don’t already have
them in the survey) from various text elements (question text, item and label)
in the survey.

If doing so, preferably you would also want to define a function that extracts
block prefixes from block names.

``` r
# Define a block prefix extraction function

block_pattern <- function(x) {
  substring(x, 1, 3)
}

mydict <- dict_generate("SV_4YyAHbAxpdbzacl",
  var_name = "easy_name",
  block_pattern = block_pattern,
  block_sep = "."
)
```

You could validate (check for potential mistakes in) the dictionary.

``` r
dict_validate(mydict)
```

And download labelled survey data with the dictionary.

``` r
survey_dat <- get_survey_data(mydict,
  unanswer_recode = -77,
  unanswer_recode_multi = 0
)
```
