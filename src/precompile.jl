using SnoopPrecompile

@precompile_setup begin
	base_path = joinpath(pkgdir(SingleCellProjections), "test/data")
	h5_path = joinpath(base_path, "500_PBMC_3p_LT_Chromium_X_50genes/filtered_feature_bc_matrix.h5")
	@precompile_all_calls begin
		counts = load10x(h5_path)
		P,N = size(counts)
		counts2 = load_counts([h5_path,h5_path]; sample_names=["a","b"])
		var_counts_fraction!(counts, "name"=>startswith("A"), "feature_type"=>==("Gene Expression"), "MyCol")
		counts.obs.group = repeat(["A","B","C"]; outer=div(N+2,3))[1:N]
		counts.obs.value = range(-1,1;length=N)
		transformed = sctransform(counts; use_cache=false, verbose=false)
		normalized = normalize_matrix(transformed)
		normalized2 = normalize_matrix(transformed, "group", "value"; scale=true)
		reduced = svd(normalized; nsv=4)
		reduced2 = svd(normalized2; nsv=4)
		fl = force_layout(reduced; ndim=2, k=10)
		ind = [1,2,3]
		counts[ind,ind], counts[ind,:]
		normalized[ind,ind], normalized[:,ind], normalized[ind,:]
		normalized2[ind,ind], normalized2[:,ind], normalized2[ind,:]
		reduced[ind,ind], reduced[:,ind], reduced[ind,:]
		fl[[2,1],ind], fl[:,ind]
		counts_proj = counts[:,ind]
		empty!(counts_proj.models)
		project(counts_proj, fl[[2,1],:]; verbose=false)
	end
end
