// Shared terminal node for 02/03/04: "Return skipped result".
// Used when no HTTP call is made (invalid input or source not configured).
return [{ json: $input.first().json.result }];
