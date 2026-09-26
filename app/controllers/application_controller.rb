class ApplicationController < ActionController::Base
  # No allow_browser gate: this is a gift for a family audience that may be on
  # an older tablet. Browsers that cannot run the module script get the
  # no-JS fallback (every photo, stacked) instead of a 406.

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes
end
