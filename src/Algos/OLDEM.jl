"""
    createLDES(L::T, s::T, n_assets::T) where T<:Int

Creates a list of LDES of length `L`, each of which is of length `s` and contains integers \
from 1 to `n_assets`. Hence, this function randomly creates a list of vectors each of which \
contains index of `s` assets.

# Arguments
- `L::T`: Number of LDES to be created.
- `s::T`: Length of each LDES. (Number of assets in each LDES)
- `n_assets::T`: Number of considered assets.

!!! note
    Note that ``s<<n_assets`` should be satisfied. Also, `L` should be a large number. The \
    authors have used `L=300` and `s=5` in their paper.

# Returns
- `::Vector{Vector{<:Int}}`: A list of LDES of length `L`.

# Example
A minimal example is as follows:
```julia
julia> createLDES(3, 2, 4)
3-element Vector{Vector{Int64}}:
 [1, 3]
 [3, 4]
 [4, 1]
```
In the above, the third subsystem contains the fourth and the first assets.
"""
function createLDES(L::T, s::T, n_assets::T) where T<:Int
  return [rand(1:n_assets, s) for 𝑙=1:L]
end

"""
    createXₜ⁽ˡ⁾(w::T, t::T, 𝑙::AbstractVector{<:Int}, x::AbstractMatrix) where T<:Int

Create a matrix of size `w` × `length(𝑙)` where ``w=i-t`` and ``𝑙={𝑙₁, 𝑙₂, \\ltods, 𝑙ₛ}``.

# Arguments
- `w::T`: Window size.
- `t::T`: Current time index.
- `𝑙::AbstractVector{<:Int}`: A vector of length `s` containing index of assets in the LDE.
- `x::AbstractMatrix`: A matrix of size `n_assets` × `t` containing the price relatives of \
assets.

# Returns
- `::AbstractMatrix`: A Xₜ⁽ˡ⁾ matrix of size ``t-i \\times j``. Where ``i=1,2,\\ldots ,w`` \
and ``j=1,2,\\ldots ,s``. Note that `length(𝑙)=s`.

# Example:
```julia
julia> x = rand(0.8:0.001:1.2, 6, 10)
6×10 Matrix{Float64}:
 1.058  1.158  1.067  0.803  0.977  1.175  0.954  1.075  1.099  1.035
 1.01   1.068  0.875  0.873  0.934  0.884  1.198  1.073  1.127  1.098
 0.897  1.115  0.995  0.833  1.151  0.839  1.104  1.166  1.151  1.11
 0.829  0.893  1.046  0.956  1.057  1.119  1.109  1.095  1.059  0.82
 1.145  1.014  0.87   1.137  1.029  0.904  1.095  1.111  1.079  1.109
 1.023  0.992  1.059  1.15   0.915  0.916  1.137  0.9    1.033  0.864

 julia> createXₜ⁽ˡ⁾(3, 5, [2, 4, 6, 3], x)
3×4 Matrix{Float64}:
 0.873  0.956  1.15   0.833
 0.875  1.046  1.059  0.995
 1.068  0.893  0.992  1.115
```
"""
function createXₜ⁽ˡ⁾(w::T, t::T, 𝑙::AbstractVector{<:Int}, x::AbstractMatrix) where T<:Int
  all(𝑙.∈Ref(1:size(x, 1))) || DomainError("$𝑙 ∉ 1:$(size(x, 1))") |> throw
  t-w>0 || DomainError("t-w<0") |> throw
  t>0   || DomainError("t<0") |> throw
  return rotl90(x[𝑙, t-w:t-1])
end

"""
    β̂ₖ⁽ˡ⁾func(Xₜ⁽ˡ⁾::AbstractMatrix, xₜₖ::AbstractVector)

Estimate unknown parameters βₖₛ⁽ˡ⁾ using OLS.

# Arguments
- `Xₜ⁽ˡ⁾::AbstractMatrix`: A matrix of size ``t-i \times j``.
- `xₜₖ::AbstractVector`: Price relative of ``k``th asset at time ``t \\to t-w+1``. In other \
words, ``x_{t,k}=\\left( x_{t,k}, x_{t-1,k}, \\ldots , x_{t-w+1,k}\\right)``.

# Returns
- `::AbstractVector`: A `Vector` of length ``j`` containing the estimated parameters.

# Example
```julia
julia> Xₜ⁽ˡ⁾ = rand(0.8:0.001:1.2, 3, 4)
3×4 Matrix{Float64}:
 0.832  0.914  1.106  0.805
 0.862  1.112  1.143  1.03
 0.922  1.114  1.092  0.835

julia> xₜₖ = rand(0.8:0.001:1.2, size(Xₜ⁽ˡ⁾, 1))
3-element Vector{Float64}:
 0.846
 0.912
 0.912

julia> β̂ₖ⁽ˡ⁾func(Xₜ⁽ˡ⁾, xₜₖ)
4-element Vector{Float64}:
 -0.4798900000000006
  0.5026091289306112
  0.34547586878629644
  0.42096800422953784
"""
function β̂ₖ⁽ˡ⁾func(Xₜ⁽ˡ⁾::AbstractMatrix, xₜₖ::AbstractVector)
  length(xₜₖ) == size(Xₜ⁽ˡ⁾, 1) || DimensionMismatch("length(xₜₖ) != size(Xₜ⁽ˡ⁾, 2)") |> throw
  xₜₖ = xₜₖ |> permutedims |> permutedims
  return (Xₜ⁽ˡ⁾'*Xₜ⁽ˡ⁾)^-1*(Xₜ⁽ˡ⁾'*xₜₖ) |> vec
end

x̂ₜ₊₁ₖ⁽ˡ⁾func(xₜ⁽ˡ⁾::T, β̂ₖ⁽ˡ⁾::T) where T<:AbstractVector = sum(xₜ⁽ˡ⁾.*β̂ₖ⁽ˡ⁾)


x = rand(0.8:0.001:1.2, 6, 10)
createXₜ⁽ˡ⁾(3, 5, [2, 4, 6], x)
