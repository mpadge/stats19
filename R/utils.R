#' Convert file names to urls
#'
#' @details
#' This function returns urls that allow data to be downloaded from the pages:
#'
#' http://data.dft.gov.uk/road-accidents-safety-data/road-accidents-safety-data/RoadSafetyData_2015.zip
#'
#' http://data.dft.gov.uk.s3.amazonaws.com/road-accidents-safety-data/dftRoadSafety_Accidents_2016
#'
#' Last updated: 22nd Nov 2018.
#' Files available from the s3 url in the default `domain` argument.
#'
#' @param file_name Optional file name to add to the url returned (empty by default)
#' @param domain The domain from where the data will be downloaded
#' @param directory The subdirectory of the url
#' @examples
#' # get_url(find_file_name(1985))
get_url = function(file_name = "",
                   domain = "http://data.dft.gov.uk.s3.amazonaws.com",
                   directory = "road-accidents-safety-data"
                   ) {
  path = file.path(domain, directory, file_name)
  path
}

#' This is a private function which does two things:
#' 1. is used to check if there is an overlapping of files with
#' multiple years. The matching between the years and the files works as follows:
#' 1979 ... 2004 ---> 1979 - 2004
#' 2005 ... 2008 ---> 2005 - 2014
#' 2009          ---> 2009
#' 2010          ---> 2010
#' 2011          ---> 2011
#' ...
#' 2018          ---> 2018
#' 2. it also does the sanity checking of the year(s) given
#'
#' @param year Year(s) vector to check.
#' @examples
#' # check_year("2018")
#' # check_year(1979:2018)
#' #> c(1979, 2005, 2015:2018)
#' # check_year(2006)
#' # check_year(1985)
check_year = function(year) {
  if(!is.numeric(year)) year = as.numeric(year)
  is_year = all(year %in% 1979:(current_year() - 1))
  if(!is_year || any(is.na(year)) || length(year) == 0) {
    msg = paste0("Years must be in range 1979:", current_year() - 1)
    stop(msg, call. = FALSE)
  }
  # valid year, continue
  if(any(year %in% 1979:2004)) {
    message("Year not in range, changing to match 1979:2004 data")
    year[year %in% 1979:2004] = 1979
  }
  # we have an overlap of year 2009 to 2014 as
  # individual zip files and
  # bundled within 2005-2014
  if(any(year %in% 2005:2008)) {
    message("Year not in range, changing to match 2005:2014 data")
    year[year %in% 2005:2014] = 2005
  }
  year = unique(year)
  year
}

# current_year()
current_year = function() as.integer(format(format(Sys.Date(), "%Y")))

#' Find file names within stats19::file_names.
#'
#' Currently, there are 52 file names to download/read data from.
#'
#' @param years Years for which data are to be found
#' @param type One of 'Accidents', 'Casualties', 'Vehicles'; defaults to 'Accidents', ignores case.
#'
#' @examples
#' find_file_name(2016)
#' find_file_name(2016, type = "Accidents")
#' find_file_name(1985, type = "Accidents")
#' find_file_name(type = "cas")
#' find_file_name(type = "accid")
#' find_file_name(2006)
#' find_file_name(2016:2017)
#' @export
find_file_name = function(years = NULL, type = NULL) {

  result = unlist(stats19::file_names, use.names = FALSE)

  if(!is.null(years)) {
    years = sapply(years, check_year)
    years_regex = paste0(years, collapse = "|")
    result = result[grep(pattern = years_regex, x = result)]
  }

  # see https://github.com/ITSLeeds/stats19/issues/21
  if(!is.null(type)) {
    result_type = result[grep(pattern = type, result, ignore.case = TRUE)]
    if(length(result_type) > 0) {
      result = result_type
    } else {
      if(is.null(years)) {
       stop("No files of that type found", call. = FALSE)
      } else {
        message("No files of that type found for that year.")
      }
    }
  }
  if(any(grepl("Stats19-Data1979-2004.zip", result))) {
    # extra warnings
    message("\033[31mThis will download 240 MB+ (1.8 GB unzipped).\033[39m")
    message("Coordinates and other variables may be unreliable in these datasets.")
    message("See https://github.com/ropensci/stats19/issues/101 and https://github.com/ropensci/stats19/issues/102")
  }

  if(length(result) < 1)
    stop("No files of that type exist", call. = FALSE)
  unique(result)
}

#' Locate a file on disk
#'
#' Helper function to locate files. Given below params, the function
#' returns 0 or more files found at location/names given.
#'
#' @param years Years for which data are to be found
#' @param type One of 'Accidents', 'Casualties', 'Vehicles'; defaults to 'Accidents', ignores case.
#' @param data_dir Super directory where dataset(s) were first downloaded to.
#' @param quiet Print out messages (files found)
#'
#' @return Character string representing the full path of a single file found,
#' list of directories where data from the Department for Transport
#' (stats19::filenames) have been downloaded, or NULL if no files were found.
#'
locate_files = function(data_dir = get_data_directory(),
                        type = NULL,
                        years = NULL,
                        quiet = FALSE) {
  stopifnot(dir.exists(data_dir))
  file_names = find_file_name(years = years, type = type)
  if(all(grepl(pattern = "csv", file_names))) {
    return(file.path(data_dir, file_names))
  }
  file_names = tools::file_path_sans_ext(file_names)
  dir_files = list.dirs(data_dir)
  # check is any file names match those on disk
  files_on_disk = vapply(file_names, function(i) any(grepl(i, dir_files)),
                logical(1))
  if(any(files_on_disk)) { # return those on disk which match file names
    files_on_disk = names(files_on_disk[files_on_disk])
  }
  return(files_on_disk)
}

#' Pin down a file on disk from four parameters.
#'
#' @param filename Character string of the filename of the .csv to read, if this
#' is given, type and years determine whether there is a target to read,
#' otherwise disk scan would be needed.
#' @param data_dir Where sets of downloaded data would be found.
#' @param year Single year for which file is to be found.
#' @param type One of: 'Accidents', 'Casualties', 'Vehicles'; ignores case.
#'
#' @return One of: path for one file, a message `More than one file found` or error if none found.
#' @export
#' @examples
#' \donttest{
#' locate_one_file()
#' locate_one_file(filename = "Cas.csv")
#' }
locate_one_file = function(filename = NULL,
                           data_dir = get_data_directory(),
                           year = NULL,
                           type = NULL) {
  # see if locate_files can pin it down
  path = locate_files(data_dir = data_dir,
                      type = type,
                      years = year,
                      quiet = TRUE)
  if(length(path) == 0) {
    stop("No files found under: ", data_dir, call. = FALSE)
  }
  # Test if path points to a single existing CSV file. See
  # https://github.com/ropensci/stats19/issues/197 for more details.
  if (length(path) == 1 && file.exists(path) && tools::file_ext(path) == "csv") {
    return(path)
  }
  scan1 = function(path, type) {
    lf = list.files(file.path(data_dir, path), ".csv$", full.names = TRUE)
    if(!is.null(type))
      lf = lf [grep(type, lf, ignore.case = TRUE)]
    return(lf)
  }
  res = unlist(lapply(path, function(i) scan1(i, type)))
  if(!is.null(filename))
    res = res [grep(filename, res)]
  if(length(res) > 1)
    return("More than one csv file found.")
  return(res)
}
utils::globalVariables(
  c("stats19_variables", "stats19_schema", "skip", "accidents_sample",
    "accidents_sample_raw", "casualties_sample", "casualties_sample_raw",
    "vehicles_sample", "vehicles_sample_raw"))
#' Generate a phrase for data download purposes
#' @examples
#' stats19:::phrase()
phrase = function() {
  txt = c(
    "Happy to go",
    "Good to go",
    "Download now",
    "Wanna do it"
  )
  paste0(
    txt [ceiling(stats::runif(1) * length(txt))],
    " (y = enter, n = N/other)? "
  )
}

#' Interactively select from options
#' @param fnames File names to select from
#' @examples
#' # fnames = c("f1", "f2")
#' # stats19:::select_file(fnames)
select_file = function(fnames) {
  message("Multiple matches. Which do you want to download?")
  selection = utils::menu(choices = fnames)
  fnames[selection]
}

#' Get data download dir
#' @examples
#' # get_data_directory()
get_data_directory = function() {
  data_directory = Sys.getenv("STATS19_DOWNLOAD_DIRECTORY")
  if(data_directory != "") {
    return(data_directory)
  }
  tempdir()
}

#' Set data download dir
#'
#' Handy function to manage `stats19` package underlying environment
#' variable. If run interactively it makes sure user does not change
#' directory by mistatke.
#'
#' @param data_path valid existing path to save downloaded files in.
#' @examples
#' # set_data_directory("MY_PATH")
set_data_directory = function(data_path) {
  force(data_path)
  set_it = function() {
    Sys.setenv(STATS19_DOWNLOAD_DIRECTORY= data_path)
    message("STATS19_DOWNLOAD_DIRECTORY is set, undo with Sys.unsetenv")
  }

  if(!dir.exists(data_path)) {
    stop("Directory does not exist, please create it first.")
    # TODO: check write permissions?
  }
  data_directory = Sys.getenv("STATS19_DOWNLOAD_DIRECTORY")
  if(data_directory != "") {
    message("STATS19_DOWNLOAD_DIRECTORY is set, change it?")
    if(interactive()) {
      c = utils::menu(sample(c("Yes", "No!")))
      if(c == 1L) {
        set_it()
      }
    } else {
      Sys.setenv(STATS19_DOWNLOAD_DIRECTORY= data_path)
      message("Overwrote STATS19_DOWNLOAD_DIRECTORY without asking.")
    }
  } else {
    set_it()
  }
}
