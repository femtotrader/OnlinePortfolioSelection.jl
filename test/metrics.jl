# Test data. Assumption: 3 assets and 40 periods.
adj_close = rand(3, 40) .* [4., 3., 2.] .+ [1., 5., 4.];
rel_pr = adj_close[:, 2:end] ./ adj_close[:, 1:end-1];
adj_close_market = rand(40);

@testset "OPSMetrics" begin
  @testset "DRICORNK" begin
    res = DRICORNK(
      adj_close,
      adj_close_market,
      1,
      2,
      2,
      2
    )

    met = OPSMetrics(
      res.b,
      rel_pr
    )

    @test isa(met, OPSMetrics)
    @test fieldnames(OPSMetrics) == propertynames(met)
  end

  @testset "CORN-K" begin
    res = CORNK(
      adj_close,
      10,
      2,
      3,
      2
    )

    met = OPSMetrics(
      res.b,
      rel_pr
    )

    @test isa(met, OPSMetrics)
    @test fieldnames(OPSMetrics) == propertynames(met)
  end

  @testset "CORN-U" begin
    res = CORNU(
      adj_close,
      7,
      2,
      0.8,
    )

    met = OPSMetrics(
      res.b,
      rel_pr
    )

    @test isa(met, OPSMetrics)
    @test fieldnames(OPSMetrics) == propertynames(met)
  end
end