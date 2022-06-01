# ------------------------------------------------------------------
# Licensed under the MIT License. See LICENSE in the project root.
# ------------------------------------------------------------------

"""
    Sort(col₁, col₂, ..., colₙ; alg=DEFAULT_UNSTABLE, lt=isless, by=identity, rev=false, order=Forward)
    Sort([col₁, col₂, ..., colₙ]; alg=DEFAULT_UNSTABLE, lt=isless, by=identity, rev=false, order=Forward)
    Sort((col₁, col₂, ..., colₙ); alg=DEFAULT_UNSTABLE, lt=isless, by=identity, rev=false, order=Forward)

Sort the table by the values of the selected columns `col₁`, `col₂`, ..., `colₙ`.
The keyword arguments are the same as in the `sort` function.

    Sort(regex; alg=DEFAULT_UNSTABLE, lt=isless, by=identity, rev=false, order=Forward)

Sort the table by the values of the columns that match with `regex`.

# Examples

```julia
Sort(:a)
Sort(:a, :c, rev=true)
Sort([1, 3, 5], by=row -> abs.(row))
Sort(("a", "c", "e"))
Sort(r"[ace]")
```

## Notes

* The row passed to `by` kwarg is the selection row, not the table row.
"""
struct Sort{S<:ColSpec,T} <: Stateless
  colspec::S
  kwargs::T
end

Sort(colspec::S; kwargs...) where {S<:ColSpec} = 
  Sort(colspec, values(kwargs))

Sort(cols::T...; kwargs...) where {T<:ColSelector} = 
  Sort(cols, values(kwargs))

# argument errors
Sort(::Tuple{}; kwargs...) = throw(ArgumentError("Cannot create a Sort object with empty tuple."))
Sort(; kwargs...) = throw(ArgumentError("Cannot create a Sort object without arguments."))

isrevertible(::Type{<:Sort}) = true

function apply(transform::Sort, table)
  cols = Tables.columns(table)
  names = Tables.columnnames(cols)
  snames = choose(transform.colspec, names)
  
  # use selected columns to calculate new order
  srows = collect(zip(Tables.getcolumn.(Ref(cols), snames)...))
  inds = sortperm(srows; transform.kwargs...)

  # sort rows
  rows = Tables.rowtable(table)
  rows = rows[inds]

  newtable = rows |> Tables.materializer(table)
  newtable, inds
end

function revert(::Sort, newtable, cache)
  # use cache to recalculate old order
  inds = sortperm(cache)

  # undo rows sort
  rows = Tables.rowtable(newtable)
  rows = rows[inds]

  rows |> Tables.materializer(newtable)
end
