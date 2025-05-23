module ClusLogModelExt

using OnlinePortfolioSelection
using Clustering:     kmeans, kmedoids, assignments, counts, silhouettes
using JuMP:           Model, @variable, @constraint, @NLobjective, set_silent, optimize!
using JuMP:           value
using Ipopt:          Optimizer
using Statistics:     cor, mean
using LinearAlgebra:  Symmetric
using Distances:      Euclidean, pairwise
using DataStructures: OrderedSet, counter

function OnlinePortfolioSelection.cluslog(
  rel_pr::AbstractMatrix{<:AbstractFloat},
  horizon::Int,
  TW::Int,
  model::Type{<:OnlinePortfolioSelection.ClusLogVariant},
  nclusters::Int,
  nclustering::Int,
  boundries::NTuple{2, AbstractFloat};
  progress::Bool=true
)
  nassets, nperiods = size(rel_pr)
  nperiods > horizon || DomainError("horizon must be less than the number of \
    samples (columns) in rel_pr"
  ) |> throw
  TW ≥ 2 || DomainError("`TW` must be ≥ 2") |> throw
  nclusters ≥ 2 || DomainError("`nclusters` must be ≥ 2") |> throw
  nclustering ≥ 1 || DomainError("`nclustering` must be ≥ 1") |> throw
  boundries[1] < boundries[2] || DomainError("The first element of `boundries` must be \
    less than the second element"
  ) |> throw
  boundries[1] ≥ 0 || DomainError("The first element of `boundries` must be ≥ 0") |> throw
  0 < boundries[2] ≤ 1 || DomainError("The second element of `boundries` must be ∈ (0, 1]"
  ) |> throw
  boundries[1] < 1/nassets || DomainError("The first element of `boundries` must be \
    less than 1/$(nassets)"
  ) |> throw
  TW < nperiods-horizon+1 || DomainError("`TW` must be < $(nperiods-horizon+1). Either \
    provide more data point, or decrease `horizon` or decrease `TW`."
  ) |> throw
  nclusters ≤ nperiods-horizon || DomainError("`nclusters` must be less than or equal to \
  $(nperiods-horizon). This is because of the provided amount of data") |> throw
  horizon > 0 || DomainError("`horizon` must be > 0") |> throw

  b = zeros(nassets, horizon)
  progress && (start = time())
  for idx_day ∈ 1:horizon
    rel_pr_ = @view rel_pr[:, 1:end-horizon+idx_day]
    for tw ∈ 2:TW
      ntw           = size(rel_pr_, 2) - tw + 1
      cor_tw        = cor_between_tws(rel_pr_, tw, ntw)
      optimal_nclus = nclusopt(model, cor_tw, nclusters)
      idx_sim_tws   = clustering(model, cor_tw, optimal_nclus, nclustering)
      isempty(idx_sim_tws) || pop!(idx_sim_tws)
      if isempty(idx_sim_tws)
        if idx_day==1
          b[:, idx_day] = ones(nassets)/nassets
        else
          b[:, idx_day] = OnlinePortfolioSelection.bAdjusted(b[:, idx_day-1], rel_pr_[:, end])
        end
      else
        day_after_similar_tws        = idx_sim_tws.+tw
        rel_pr_day_after_similar_tws = @view rel_pr_[:, day_after_similar_tws]
        cor_similar_tws              = cor_tw[end, idx_sim_tws]
        b[:, idx_day]                = optimization(cor_similar_tws, rel_pr_day_after_similar_tws, boundries)
      end
    end
    progress && OnlinePortfolioSelection.progressbar(stdout, horizon, idx_day, start_time=start)
  end
  return OPSAlgorithm(nassets, b, cluslogalgname(model))
end

function cor_between_tws(rel_pr::AbstractMatrix{<:AbstractFloat}, len_tw, ntw)
  nassets = size(rel_pr, 1)
  eltype_ = eltype(rel_pr)
  cor_tw  = ones(eltype_, ntw, ntw)

  for idx₁ ∈ 1:ntw-1
    coef = idx₁-1
    a = 1+nassets*coef
    b = a+(len_tw*nassets-1)
    for (counter_, idx₂) ∈ enumerate(idx₁+1:ntw)
      a_                 = a+(nassets*counter_)
      b_                 = a_+(len_tw*nassets-1)
      vec₁               = @view rel_pr[a:b]
      vec₂               = @view rel_pr[a_:b_]
      cor_tw[idx₁, idx₂] = cor(vec₁, vec₂)
    end
  end

  return Symmetric(cor_tw) |> Matrix
end

function nclusopt(model::Type{<:OnlinePortfolioSelection.ClusLogVariant}, cor_tw, nclusters)
  sils      = zeros(nclusters)
  for nclus ∈ 2:nclusters
    fitted  = clustering(model, cor_tw, nclus)
    dists   = pairwise(Euclidean(), cor_tw)
    sils[nclus-1] = silhouettes(fitted, cor_tw) |> mean
  end
  return argmax(sils) + 1
end

"""
    identityfinder(model, idxLastTW)

Find the index of time windows that are in the same cluster as the latest time window.
"""
function identityfinder(model, idxLastTW)
  identities                   = assignments(model)
  indice_latest_tw_cluster     = identities[idxLastTW]
  idx_tws_in_latest_tw_cluster = findall(
    identities .== indice_latest_tw_cluster
  )
  return idx_tws_in_latest_tw_cluster
end

function clustering(::Type{KMNLOG}, cor_tw, nclusters)
  fitted = kmeans(cor_tw, nclusters)
  return fitted
end

function clustering(::Type{KMDLOG}, cor_tw, nclusters)
  dists  = pairwise(Euclidean(), cor_tw)
  fitted = kmedoids(dists, nclusters)
  return fitted
end

function clustering(model::Type{<:OnlinePortfolioSelection.ClusLogVariant}, cor_tw, nclusters, nclustering)
  twoccurance = Vector{Int}(undef, 0)
  ntw         = size(cor_tw, 1)
  for clus_time ∈ 1:nclustering
    fitted      = clustering(model, cor_tw, nclusters)
    idx_sim_TWs = identityfinder(fitted, ntw)
    push!(twoccurance, idx_sim_TWs...)
  end
  counter_    = counter(twoccurance)
  thresh      = round(Int, 0.8*nclustering)
  idx_sim_TWs = filter(x -> counter_[x] ≥ thresh, keys(counter_))
  return idx_sim_TWs |> OrderedSet |> sort |> collect
end

function optimization(corrs::AbstractVector, relpr::AbstractMatrix, boundries::NTuple{2, AbstractFloat})
  lb, ub   = boundries
  nassets  = size(relpr, 1)
  optmodel = Model(Optimizer)
  @variable(optmodel, lb ≤ w[1:nassets] ≤ ub)
  @constraint(optmodel, sum(w)==1)
  @NLobjective(
    optmodel,
    Max,
    sum(
      corrs[i] * log10(
        sum(
          w[j] * relpr[j, i]
          for j ∈ 1:nassets
        )
      )
      for i ∈ 1:length(corrs)
    )
  )
  set_silent(optmodel)
  optimize!(optmodel)
  return value.(w)
end

cluslogalgname(::Type{KMNLOG}) = "KMNLOG"
cluslogalgname(::Type{KMDLOG}) = "KMDLOG"
end #module
