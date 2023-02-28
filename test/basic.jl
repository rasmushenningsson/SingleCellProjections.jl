isgz(fn) = lowercase(splitext(fn)[2])==".gz"
_open(f, fn) = open(fn) do io
    f(isgz(fn) ? GzipDecompressorStream(io) : io)
end

read_matrix(fn,delim=',') = _open(io->readdlm(io,delim,Int), fn)
read_strings(fn,delim=',') = _open(io->readdlm(io,delim,String), fn)

function simple_logtransform(X, scale_factor)
	s = sum(X; dims=1)
	log2.( 1 .+ X.*scale_factor./max.(1,s) )
end

materialize(X::MatrixExpression) = X*I(size(X,2))

function pairwise_dist(X)
	K = X'X
	d = diag(K)
	D2 = d .+ d' .- 2.0.*K
	sqrt.(max.(0.0, D2))
end

function ncommon_neighbors(A,B; k=20)
	@assert size(A,2)==size(B,2)
	N = size(A,2)
	Dr = pairwise_dist(A)
	Df = pairwise_dist(B)
	ncommon = zeros(Int,N)
	for i in 1:N
		a = sortperm(Dr[:,i])[1:k]
		b = sortperm(Df[:,i])[1:k]
		ncommon[i] = length(intersect(a,b))
	end
	ncommon
end


@testset "Basic Workflow" begin
	pbmc_path = joinpath(pkgdir(SingleCellProjections), "test/data/500_PBMC_3p_LT_Chromium_X_50genes")
	h5_path = joinpath(pbmc_path, "filtered_feature_bc_matrix.h5")
	mtx_path = joinpath(pbmc_path, "filtered_feature_bc_matrix/matrix.mtx.gz")

    expected_mat = read_matrix(joinpath(pbmc_path,"expected_matrix.csv"))
    expected_nnz = count(!iszero, expected_mat)
    expected_feature_ids = vec(read_strings(joinpath(pbmc_path,"expected_feature_ids.csv")))
    expected_barcodes = vec(read_strings(joinpath(pbmc_path,"expected_barcodes.csv")))

    expected_feature_names = read_strings(joinpath(pbmc_path,"filtered_feature_bc_matrix/features.tsv.gz"),'\t')[:,2]
    expected_feature_types = fill("Gene Expression", 50)
    expected_feature_genome = fill("GRCh38", 50)


	@testset "load10x $(split(basename(p),'.';limit=2)[2]) lazy=$lazy" for p in (h5_path,mtx_path), lazy in (false, true)
		counts = load10x(p; lazy)
		@test size(counts)==(50,587)
		@test nnz(counts.matrix) == expected_nnz

		@test Set(names(counts.obs)) == Set(("id", "barcode"))
		@test counts.obs.id == expected_barcodes
		@test counts.obs.barcode == expected_barcodes

		if p==h5_path
			@test Set(names(counts.var)) == Set(("id", "name", "feature_type", "genome"))
			@test counts.var.genome == expected_feature_genome
		else
			@test Set(names(counts.var)) == Set(("id", "name", "feature_type"))
		end
		@test counts.var.id == expected_feature_ids
		@test counts.var.name == expected_feature_names
		@test counts.var.feature_type == expected_feature_types

		@test counts.obs_id_cols == ["id"]
		@test counts.var_id_cols == ["id", "feature_type"]

		if lazy
			@test counts.matrix.filename == p
			counts = load_counts(counts)
		end

		@test counts.matrix == expected_mat
		@test counts.matrix isa SparseMatrixCSC{Int64,Int32}
	end


	@testset "load_counts $(split(basename(p),'.';limit=2)[2]) lazy=$lazy lazy_merge=$lazy_merge" for p in (h5_path,mtx_path), lazy in (false, true), lazy_merge in (false, true)
		counts = load_counts([p,p]; sample_names=["a","b"], lazy, lazy_merge)

		@test size(counts)==(50,587*2)
		@test nnz(counts.matrix) == expected_nnz*2

		@test Set(names(counts.obs)) == Set(("id", "sampleName", "barcode"))
		@test counts.obs.id == [string.("a_",expected_barcodes); string.("b_",expected_barcodes)]
		@test counts.obs.sampleName == [fill("a",587); fill("b",587)]
		@test counts.obs.barcode == [expected_barcodes; expected_barcodes]

		if p==h5_path
			@test Set(names(counts.var)) == Set(("id", "name", "feature_type", "genome"))
			@test counts.var.genome == expected_feature_genome
		else
			@test Set(names(counts.var)) == Set(("id", "name", "feature_type"))
		end
		@test counts.var.id == expected_feature_ids
		@test counts.var.name == expected_feature_names
		@test counts.var.feature_type == expected_feature_types

		@test counts.obs_id_cols == ["id"]
		@test counts.var_id_cols == ["id", "feature_type"]

		if lazy_merge
			counts = load_counts(counts)
		end

		@test counts.matrix == [expected_mat expected_mat]
		@test counts.matrix isa SparseMatrixCSC{Int64,Int32}
	end

	# TODO: load_counts with user-provided load function

	counts = load10x(h5_path)

	@testset "logtransform scale_factor=$scale_factor" for scale_factor in (10_000, 1_000)
		kwargs = scale_factor == 10_000 ? (;) : (;scale_factor)
		l = logtransform(counts; kwargs...)
		@test l.matrix.matrix ≈ simple_logtransform(expected_mat, scale_factor)
		@test nnz(l.matrix.matrix) == expected_nnz
	end

	transformed = sctransform(counts; use_cache=false)
	@testset "sctransform" begin
		params = scparams(counts.matrix, counts.var; use_cache=false)

		@test params.logGeneMean ≈ transformed.var.logGeneMean
		@test params.outlier == transformed.var.outlier
		@test params.beta0 ≈ transformed.var.beta0
		@test params.beta1 ≈ transformed.var.beta1
		@test params.theta ≈ transformed.var.theta

		sct = sctransform(counts.matrix, counts.var, params)

		@test size(transformed.matrix) == size(sct)
		@test materialize(transformed.matrix) ≈ sct rtol=1e-3
	end

	# TODO: tf_idf_transform

	transformed.obs.group = rand(StableRNG(904), ("A","B","C"), size(transformed,2))
	transformed.obs.value = 1 .+ randn(StableRNG(905), size(transformed,2))

	X = materialize(transformed.matrix)
	Xc = (X.-mean(X; dims=2))
	Xs = Xc ./ std(X; dims=2)

	# categorical
	Xcat = copy(X)
	g = transformed.obs.group
	for c in unique(g)
		Xcat[:, c.==g] .-= mean(Xcat[:, c.==g]; dims=2)
	end
	Xcat_s = Xcat ./ std(Xcat; dims=2)

	# numerical
	v = transformed.obs.value .- mean(transformed.obs.value)
	β = Xc/v'
	Xnum = Xc .- β*v'
	Xnum_s = Xnum ./ std(Xnum; dims=2)

	# combined
	D = [g.=="A" g.=="B" g.=="C" v]
	β = X / D'
	Xcom = X .- β*D'
	Xcom_s = Xcom ./ std(Xcom; dims=2)

	@testset "normalize" begin
		@test materialize(normalize_matrix(transformed).matrix) ≈ Xc
		@test materialize(normalize_matrix(transformed; scale=true).matrix) ≈ Xs

		@test materialize(normalize_matrix(transformed, "group").matrix) ≈ Xcat
		@test materialize(normalize_matrix(transformed, "group"; scale=true).matrix) ≈ Xcat_s

		@test materialize(normalize_matrix(transformed, "value").matrix) ≈ Xnum
		@test materialize(normalize_matrix(transformed, "value"; scale=true).matrix) ≈ Xnum_s

		@test materialize(normalize_matrix(transformed, "group", "value").matrix) ≈ Xcom
		@test materialize(normalize_matrix(transformed, "group", "value"; scale=true).matrix) ≈ Xcom_s
	end

	normalized = normalize_matrix(transformed, "group", "value")

	@testset "svd" begin
		reduced = svd(normalized; nsv=3, subspacedims=24, niter=4, rng=StableRNG(102))
		F = svd(Xcom)
		@test size(reduced)==size(transformed)
		@test reduced.matrix.S ≈ F.S[1:3] rtol=1e-3
		@test abs.(reduced.matrix.U'F.U[:,1:3]) ≈ I(3) rtol=1e-3
		@test abs.(reduced.matrix.V'F.V[:,1:3]) ≈ I(3) rtol=1e-3
	end

	reduced = svd(normalized; nsv=10, niter=4, rng=StableRNG(102))
	@testset "force layout seed=$seed" for seed in 1:5
		fl = force_layout(reduced; ndim=3, k=10, rng=StableRNG(seed))
		# Sanity check output by checking that there is a descent overlap between nearest neighbors
		ncommon = ncommon_neighbors(obs_coordinates(fl), obs_coordinates(reduced))
		@test mean(ncommon) > 8
	end

	@testset "UMAP" begin
		umapped = umap(reduced, 3)
		# Sanity check output by checking that there is a descent overlap between nearest neighbors
		ncommon = ncommon_neighbors(obs_coordinates(umapped), obs_coordinates(reduced))
		@test mean(ncommon) > 9
	end

	@testset "t-SNE" begin
		t = tsne(reduced, 3)
		# Sanity check output by checking that there is a descent overlap between nearest neighbors
		ncommon = ncommon_neighbors(obs_coordinates(t), obs_coordinates(reduced))
		@test mean(ncommon) > 9
	end

	# TODO: filter (before/after different steps)
	# TODO: annotation stuff
end
