module OnlinePortfolioSelection

include("Algos/CRP.jl")
include("Algos/EG.jl")
include("Algos/RPRT.jl")
include("Algos/UP.jl")
include("Algos/CORN.jl")
include("Algos/DRICORNK.jl")
include("Tools/metrics.jl")
include("Types/Algorithms.jl")
include("Tools/show.jl")
include("Algos/BS.jl")

export up, eg, cornu, cornk, dricornk, crp, bs
export OPSMetrics, sn, apy, ann_std, ann_sharpe, mdd, calmar
export OPSAlgorithm

end #module