# Relative prices of 3 assets for 10 days
rel_pr = [
1.01774   1.00422  1.01267   1.00338   0.978882  1.00591   1.00929  1.00507  0.982264  0.991551
0.994283  1.0      0.988085  0.995235  0.968543  0.987609  1.00763  1.0      1.00906   1.03146
1.00952   1.01587  1.0127    0.998415  0.969844  1.00317   1.00317  1.00794  1.01429   1.01905
]

@testset "Bᵏ" begin
  @testset "with valid arguments" begin
    res = bk(rel_pr, 2, 2, 0.1)

    @test sum(res.b, dims=1) .|> isapprox(1.) |> all

    @test size(res.b) == size(rel_pr)
  end

  @testset "with unvalid c" begin
    @test_throws DomainError bk(rel_pr, 2, 2, 1.1)
    @test_throws DomainError bk(rel_pr, 2, 2, -0.1)
    @test_throws DomainError bk(rel_pr, 0, 1, 0.2)
    @test_throws DomainError bk(rel_pr, 1, 0, 0.2)
  end
end
