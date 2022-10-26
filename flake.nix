{
  description = "flake build utility functions";
  inputs = {
    base0.url       = "github:sixears/base0/r0.0.4.0";
    flake-utils.url = "github:numtide/flake-utils/c0e246b9";
  };
  outputs = { self, base0, flake-utils }: {
    lib = import ./. { inherit flake-utils; } ;
  };
}
