# ------------------------------------------------------------------
# Licensed under the MIT License. See LICENSE in the project root.
# ------------------------------------------------------------------

"""
    EigenAnalysis(proj; ndim=nothing)

The eigenanalysis of the covariance with a given projection `proj`.
The `ndim` keyword argument is the number of dimensions of the output.

## Projections

* `:V` - Uncorrelated variables (PCA transform)
* `:VD` - Uncorrelated variables and variance one (DRS transform)
* `:VDV` - Uncorrelated variables and variance one (SDS transformation)

The `:V` projection used in the PCA transform projects the data on the eigenvectors
V of the covariance matrix.

The `:VD` projection used in the DRS transform. Similar to the `:V` projection,
but the eigenvectors are multiplied by the squared inverse of the eigenvalues D.

The `:VDV` projection used in the SDS transform. Similar to the `:VD` transform,
but the data is projected back to the basis of the original variables using the Vᵀ matrix.

See [https://geostatisticslessons.com/lessons/sphereingmaf](https://geostatisticslessons.com/lessons/sphereingmaf)
for more details about these three variants of eigenanalysis.

# Examples

```julia
EigenAnalysis(:V)
EigenAnalysis(:VD)
EigenAnalysis(:VDV)
EigenAnalysis(:V, ndim=2)
```
"""
struct EigenAnalysis <: Transform
  proj::Symbol
  ndim::Union{Int,Nothing}

  function EigenAnalysis(proj; ndim=nothing)
    @assert proj ∈ (:V, :VD, :VDV) "Invalid projection."
    new(proj, ndim)
  end
end

assertions(::Type{EigenAnalysis}) = [assert_continuous]

isrevertible(::Type{EigenAnalysis}) = true

_ndim(ndim::Int, X) = ndim
_ndim(ndim::Nothing, X) = size(X, 2)

function apply(transform::EigenAnalysis, table)
  # basic checks
  for assertion in assertions(transform)
    assertion(table)
  end

  # original columns names
  cols = Tables.columns(table)
  onames = Tables.columnnames(cols)

  # table as matrix
  X = Tables.matrix(table)

  # output dim
  ndim = _ndim(transform.ndim, X)

  # center the data
  μ = mean(X, dims=1)
  Y = X .- μ

  # eigenanalysis of covariance
  S, S⁻¹ = eigenmatrices(transform, Y)

  # project the data
  Z = Y * S

  # discarted and selected coluns
  D = Z[:, ndim+1:end]
  Z = Z[:, 1:ndim]

  # column names
  names = [Symbol(:pc, d) for d in 1:ndim]

  # table with transformed columns
  𝒯 = (; zip(names, eachcol(Z))...)
  newtable = 𝒯 |> Tables.materializer(table)

  newtable, (μ, S, S⁻¹, D, onames)
end

function revert(::EigenAnalysis, newtable, cache)
  # table as matrix
  Z = Tables.matrix(newtable)

  # retrieve cache
  μ, S, S⁻¹, D, onames = cache

  # undo projection
  Y = hcat(Z, D) * S⁻¹

  # undo centering
  X = Y .+ μ

  # table with original columns
  𝒯 = (; zip(onames, eachcol(X))...)
  𝒯 |> Tables.materializer(newtable)
end

function reapply(transform::EigenAnalysis, table, cache)
  # basic checks
  for assertion in assertions(transform)
    assertion(table)
  end

  # table as matrix
  X = Tables.matrix(table)

  # output dim
  ndim = _ndim(transform.ndim, X)

  # retrieve cache
  μ, S, S⁻¹, D, onames = cache

  # center the data
  Y = X .- μ

  # project the data
  Z = Y * S

  # selected coluns
  Z = Z[:, 1:ndim]

  # column names
  names = [Symbol(:pc, d) for d in 1:ndim]

  # table with transformed columns
  𝒯 = (; zip(names, eachcol(Z))...)
  𝒯 |> Tables.materializer(table)
end

function eigenmatrices(transform, Y)
  proj = transform.proj

  Σ = cov(Y)
  F = eigen(Σ)
  λ = F.values[end:-1:1]
  V = F.vectors[:, end:-1:1]

  if proj == :V
    S   = V
    S⁻¹ = transpose(V)
  elseif proj == :VD
    Λ   = Diagonal(sqrt.(λ))
    S   = V * inv(Λ)
    S⁻¹ = Λ * transpose(V)
  elseif proj == :VDV
    Λ   = Diagonal(sqrt.(λ))
    S   = V * inv(Λ) * transpose(V)
    S⁻¹ = V * Λ * transpose(V)
  end

  S, S⁻¹
end

"""
    PCA(; ndim=nothing)

The PCA transform is a shortcut for
`ZScore() → EigenAnalysis(:V; ndim)`.

See also: [`ZScore`](@ref), [`EigenAnalysis`](@ref).

# Examples

```julia
PCA()
PCA(ndim=2)
```
"""
PCA(; ndim=nothing) = ZScore() → EigenAnalysis(:V; ndim)

"""
    DRS(; ndim=nothing)

The DRS transform is a shortcut for
`ZScore() → EigenAnalysis(:VD; ndim)`.

See also: [`ZScore`](@ref), [`EigenAnalysis`](@ref).

# Examples

```julia
DRS()
DRS(ndim=3)
```
"""
DRS(; ndim=nothing) = ZScore() → EigenAnalysis(:VD; ndim)

"""
    SDS(; ndim=nothing)

The SDS transform is a shortcut for
`ZScore() → EigenAnalysis(:VDV; ndim)`.

See also: [`ZScore`](@ref), [`EigenAnalysis`](@ref).

# Examples

```julia
SDS()
SDS(ndim=4)
```
"""
SDS(; ndim=nothing) = ZScore() → EigenAnalysis(:VDV; ndim)
