# Shared library for aggregating package categories in dev-home.
# Each category file is a function that takes a set of arguments (at minimum { pkgs })
# and returns a list of packages.
{ pkgs }:

{
  # Aggregate a list of category files into a single packages list.
  # Each category is imported with the given arguments and its result is appended.
  concatCategories =
    { categories
    , args
    }:
    pkgs.lib.concatMap (category: import category args) categories;
}
