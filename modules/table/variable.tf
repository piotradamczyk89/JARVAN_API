variable "tables" {
  type = map(object({
    hash_key  = object({ name = string, type = string })
    range_key = optional(list(object({ name = string, type = string })), [])
  }))
}
