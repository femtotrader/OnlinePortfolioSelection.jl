"""
    locate_sim(rel_price::Matrix{Float64}, w::Int, T::Int, ρ::Float64)

Find similar time windows based on the correlation coefficient threshold.

# Arguments
- `rel_price::Matrix{Float64}`: Relative prices of assets.
- `w::Int`: length of time window.
- `T::Int`: Total number of periods.
- `ρ::Float64`: correlation coefficient threshold.

# Returns
- `Vector{Int}`: Index of similar time windows.
"""
function locate_sim(rel_price::Matrix{T1}, w::T2, T::T2, ρ::T1) where {T1<:Float64, T2<:Int}
  idx_day_after_tw = Vector{T2}()

  # current time window
  curr_tw = Base.Flatten(rel_price[:, end-w+1:end])

  # Number of time windows
  n_tw = T-w+1

  # n_tw-1: because we don't want to calculate corr between the
  # currrent w and itself. So, the current time window is excluded.
  for idx_tw=1:n_tw-1
    twᵢ = Base.Flatten(rel_price[:, idx_tw:w+idx_tw-1])
    if cor(collect(curr_tw), collect(twᵢ))≥ρ
      push!(idx_day_after_tw, idx_tw)
    end
  end

  idx_day_after_tw
end;

"""
    final_weights(q::T, s::Vector{T}, b::Matrix{T})::Vector{T} where T<:Float64

Calculate the final weights of assets according to the experts.

# Arguments
- `q::T`: The portion of contribution made by each of the experts.
- `s::Vector{T}`: Total wealth achieved by each expert in the current period.
- `b::Matrix{T}`: Weights of assets achieved by each expert in the current period.

# Returns
- `Vector{T}`: Final weights of assets in the current period.
"""
function final_weights(q::T, s::Vector{T}, b::Matrix{T})::Vector{T} where T<:Float64
  numerator_ = zeros(T, size(b, 1))
  denominator_ = zero(T)
  for idx_expert ∈ eachindex(s)
    qs = q*s[idx_expert]
    numerator_+=qs*b[:, idx_expert]
    denominator_+=qs
  end

  bₜ = numerator_/denominator_
  normalizer!(bₜ)
  bₜ
end;