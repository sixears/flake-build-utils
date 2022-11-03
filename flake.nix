{
  description = "flake build utility functions";
  inputs = {
    flake-utils.url = "github:numtide/flake-utils/c0e246b9";
  };
  outputs = { self, flake-utils }: {
    lib = import ./. { inherit flake-utils; } ;
  };
}
