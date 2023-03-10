# SingleCellProjections.jl

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://rasmushenningsson.github.io/SingleCellProjections.jl/dev/)
[![Build Status](https://github.com/rasmushenningsson/SCTransform.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/rasmushenningsson/SCTransform.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/rasmushenningsson/SingleCellProjections.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/rasmushenningsson/SingleCellProjections.jl)


SingleCellProjections.jl is an easy to use and powerful package for analysis of Single Cell Expression data in Julia.
It is faster and uses less memory than existing solutions since the data is internally represented as expressions of sparse and low rank matrices, instead of storing huge dense matrices.
In particular, it efficiently performs PCA (Principal Component Analysis), a natural starting point for downstream analysis, and supports both standard workflows and projections onto a base data set.

## Installation
Install SingleCellProjections.jl by running the following commands in Julia:

```julia
using Pkg
Pkg.add("SingleCellProjections")
```

## Threading
SingleCellProjections.jl relies heavily on threading. Please make sure to [enable threading in Julia](https://docs.julialang.org/en/v1/manual/multi-threading/) to dramatically improve computation speed.


## PBMC Example
For this example we will use PBMC data from the paper [Integrated analysis of multimodal single-cell data](https://www.sciencedirect.com/science/article/pii/S0092867421005833) by Hao et al.
You can find the original data [here](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE164378), in MatrixMarker (.mtx) format.
For convenience, you can [download the samples recompressed as .h5 files](https://github.com/rasmushenningsson/SingleCellExampleData).
Direct links:
* [Cell annotations (.csv.gz)](https://github.com/rasmushenningsson/SingleCellExampleData/releases/download/GSE164378_RNA_ADT_3P/GSE164378_RNA_ADT_3P.csv.gz)
* [Donor P1 (.h5)](https://github.com/rasmushenningsson/SingleCellExampleData/releases/download/GSE164378_RNA_ADT_3P/GSE164378_RNA_ADT_3P_P1.h5)
* [Donor P2 (.h5)](https://github.com/rasmushenningsson/SingleCellExampleData/releases/download/GSE164378_RNA_ADT_3P/GSE164378_RNA_ADT_3P_P2.h5)
* [Donor P3 (.h5)](https://github.com/rasmushenningsson/SingleCellExampleData/releases/download/GSE164378_RNA_ADT_3P/GSE164378_RNA_ADT_3P_P3.h5)
* [Donor P4 (.h5)](https://github.com/rasmushenningsson/SingleCellExampleData/releases/download/GSE164378_RNA_ADT_3P/GSE164378_RNA_ADT_3P_P4.h5)
* [Donor P5 (.h5)](https://github.com/rasmushenningsson/SingleCellExampleData/releases/download/GSE164378_RNA_ADT_3P/GSE164378_RNA_ADT_3P_P5.h5)
* [Donor P6 (.h5)](https://github.com/rasmushenningsson/SingleCellExampleData/releases/download/GSE164378_RNA_ADT_3P/GSE164378_RNA_ADT_3P_P6.h5)
* [Donor P7 (.h5)](https://github.com/rasmushenningsson/SingleCellExampleData/releases/download/GSE164378_RNA_ADT_3P/GSE164378_RNA_ADT_3P_P7.h5)
* [Donor P8 (.h5)](https://github.com/rasmushenningsson/SingleCellExampleData/releases/download/GSE164378_RNA_ADT_3P/GSE164378_RNA_ADT_3P_P8.h5)

First we load `SingleCellProjections` and the packages `DataFrames` and `CSV` for handling annotations.
```julia
julia> using SingleCellProjections, DataFrames, CSV
```

### Loading Data
Then we load samples "P1" and "P2", by specifiying the paths to the files and naming them.
```julia
julia> base_path = "/path/to/downloads/";

julia> sample_paths = joinpath.(base_path, ["GSE164378_RNA_ADT_3P_P1.h5", "GSE164378_RNA_ADT_3P_P2.h5"]);

julia> counts = load_counts(sample_paths; sample_names=["P1","P2"])
DataMatrix (33766 variables and 35340 observations)
  SparseArrays.SparseMatrixCSC{Int64, Int32}
  Variables: id, feature_type, name, genome, read, pattern, sequence
  Observations: id, sampleName, barcode
```

Data sets in `SingleCellProjections` are represented as `DataMatrix` objects, which are matrices with annotations for `var` (variables/genes/features) and `obs` (observations, typically cells).
Above, `counts` is a `DataMatrix` where the counts are stored in a sparse matrix.
You can also see the available annotations for variables and observations.
To access the different parts, use:
* `counts.matrix` - For the matrix
* `counts.var` - Variable annotations (`DataFrame`)
* `counts.obs` - Observation annotations (`DataFrame`)


### Cell Annotations
Here we compute a new `obs` annotation where we count the fraction of reads coming from Mitochondrial genes for each cell:
```julia
julia> var_counts_fraction!(counts, "name"=>contains(r"^MT-"), "feature_type"=>isequal("Gene Expression"), "fraction_mt")
DataMatrix (33766 variables and 35340 observations)
  SparseArrays.SparseMatrixCSC{Int64, Int32}
  Variables: id, feature_type, name, genome, read, pattern, sequence
  Observations: id, sampleName, barcode, fraction_mt
  Models: VarCountsFractionModel(subset_size=13, total_size=33538, col="fraction_mt")
```
Note that the new annotation `fraction_mt` is present in the output.

We will also load some more cell annotations from the provided file.
```julia
julia> cell_annotations = CSV.read(joinpath(base_path, "GSE164378_RNA_ADT_3P.csv.gz"), DataFrame);

julia> leftjoin!(counts.obs, cell_annotations; on=:barcode);
```
To merge, we use the `DataFrames` function `leftjoin!`, since it takes care of matching the cells in `counts` to the cells in `cell_annotations` based on the `:barcode` column.

Let's look at some annotations for the first few cells:
```julia
julia> counts.obs[1:6,["id","sampleName","barcode","fraction_mt","celltype.l1"]]
6??5 DataFrame
 Row ??? id                      sampleName  barcode              fraction_mt  celltype.l1
     ??? String                  String      String               Float64      String7?
???????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????
   1 ??? P1_L1_AAACCCAAGACATACA  P1          L1_AAACCCAAGACATACA    0.0330832  CD4 T
   2 ??? P1_L1_AAACCCACATCGGTTA  P1          L1_AAACCCACATCGGTTA    0.0649309  Mono
   3 ??? P1_L1_AAACCCAGTGGAACAC  P1          L1_AAACCCAGTGGAACAC    0.0541372  NK
   4 ??? P1_L1_AAACCCATCTGCGGAC  P1          L1_AAACCCATCTGCGGAC    0.0712244  CD4 T
   5 ??? P1_L1_AAACGAAAGTTACTCG  P1          L1_AAACGAAAGTTACTCG    0.0625228  CD4 T
   6 ??? P1_L1_AAACGAACAATGAGCG  P1          L1_AAACGAACAATGAGCG    0.0641008  CD4 T
```

### Transformation
The raw counts data is not suitable for analyses like PCA, since the data is far from normally distributed.
A common strategy to handle this is to transform the data.
Here we will use [SCTransform](https://github.com/rasmushenningsson/SCTransform.jl) (see also [original sctransform implementation in R](https://github.com/satijalab/sctransform)).
```
julia> transformed = sctransform(counts)
DataMatrix (20239 variables and 35340 observations)
  A+B???B???B???
  Variables: id, feature_type, name, genome, read, pattern, sequence, logGeneMean, outlier, beta0, ...
  Observations: id, sampleName, barcode, fraction_mt, nCount_ADT, nFeature_ADT, nCount_RNA, nFeature_RNA, orig.ident, lane, ...
  Models: SCTransformModel(nvar=20239, clip=34.32), VarCountsFraction
```
From the output, we see that the number of variables have been reduced, since the default `sctransform` options remove variables present in very few cells and only keeps variables with `feature_type` set to `"Gene Expression"`.

The matrix is now shown as `A+B???B???B???`.
This is normally not very important from the user's point of view, but it is critical for explaining how `SingleCellProjections` can be fast and not use too much memory.
Instead of storing the SCTransformed matrix as a huge dense matrix, it is stored in memory as a `MatrixExpression`, in this case a sparse matrix `A` plus a product of three smaller matrices `B???`,`B???` and `B???`.


### Normalization
After transformation we always want to normalize the data.
At the very least, data should be centered for PCA to work properly, this can be achieved by just running `normalize_matrix` with the default parameters.
Here, we also want to regress out `"fraction_mt"`. You can add more `obs` annotations (categorical and/or numerical) to regress out if you need.
```julia
julia> normalized = normalize_matrix(transformed, "fraction_mt")
DataMatrix (20239 variables and 35340 observations)
  A+B???B???B???+(-??)X'
  Variables: id, feature_type, name, genome, read, pattern, sequence, logGeneMean, outlier, beta0, ...
  Observations: id, sampleName, barcode, fraction_mt, nCount_ADT, nFeature_ADT, nCount_RNA, nFeature_RNA, orig.ident, lane, ...
  Models: NormalizationModel(rank=2, ~1+num(fraction_mt)), SCTransform, VarCountsFraction
```
Now the matrix is shown as `A+B???B???B???+(-??)X'`, i.e. another low-rank term was added to handle the normalization/regression.
The first two terms are reused to make sure memory is not wasted.

### Filtering
It is possible to filter variables and observations.
Here we keep all cells that are not labeled as `"other"`.
```julia
julia> filtered = filter_obs("celltype.l1"=>!isequal("other"), normalized);
```

### Principal Component Analysis (PCA)
Now we are ready to perform Principal Component Analysis (PCA).
This is computed by the Singular Value Decomposition (SVD), so we should call the `svd` function.
The number of dimensions is specified using the `nsv` parameter.
```julia
julia> reduced = svd(filtered; nsv=20)
DataMatrix (20239 variables and 34639 observations)
  SVD (20 dimensions)
  Variables: id, feature_type, name, genome, read, pattern, sequence, logGeneMean, outlier, beta0, ...
  Observations: id, sampleName, barcode, fraction_mt, nCount_ADT, nFeature_ADT, nCount_RNA, nFeature_RNA, orig.ident, lane, ...
  Models: SVDModel(nsv=20), Filter, Normalization, SCTransform, VarCountsFraction
```
The matrix is now stored as an `SVD` object, which includes low dimensional representations of the observations and variables.
To retrieve the low dimensional coordinates, use `obs_coordinates` and `var_coordinates` respectively.

![Principal Component Analysis](https://user-images.githubusercontent.com/16546530/213447197-b417b050-8d17-490b-9d2c-7acff684a67d.svg)

[Download interactive PCA plot](https://github.com/rasmushenningsson/SingleCellProjections.jl/files/10456817/svd.zip).


### Visualization
<details>
<summary>Expand this to show some example PlotlyJS plotting code.</summary>

You can of course use your own favorite plotting library instead.
Use `obs_coordinates` to get the coordinates for each cell, and `data.obs` to access cell annotations for coloring.

```julia
using PlotlyJS
function plot_categorical_3d(data, annotation; marker_size=3)
    points = obs_coordinates(data)
    traces = GenericTrace[]
    for sub in groupby(data.obs, annotation; sort=true)
        value = sub[1,annotation]
        ind = parentindices(sub)[1]
        push!(traces, scatter3d(;x=points[1,ind], y=points[2,ind], z=points[3,ind], mode="markers", marker_size, name=value))
    end
    plot(traces, Layout(;legend=attr(itemsizing="constant")))
end
```

Use it like this:
```julia
julia> plot_categorical_3d(reduced, "celltype.l1")
```
</details>

For visualization purposes, it is often useful to further reduce the dimension after running PCA.
(In contrast, analyses are generally run on the PCA/normalized/original data, since the methods below necessarily distort the data to force it down to 2 or 3 dimensions.)


#### Force Layout
Force Layout plots (also known as SPRING Plots) are created like this:
```julia
julia> fl = force_layout(reduced; ndim=3, k=100)
DataMatrix (3 variables and 34639 observations)
  Matrix{Float64}
  Variables: id
  Observations: id, sampleName, barcode, fraction_mt, nCount_ADT, nFeature_ADT, nCount_RNA, nFeature_RNA, orig.ident, lane, ...
  Models: NearestNeighborModel(base="force_layout", k=10), SVD, Filter, Normalization, SCTransform, ...
```
![force_layout](https://user-images.githubusercontent.com/16546530/213448020-ec2e8e14-90b7-4be7-88be-a9ab87d86c2c.svg)

[Download interactive Force Layout plot](https://github.com/rasmushenningsson/SingleCellProjections.jl/files/10456840/force_layout.zip).



#### UMAP
`SingleCellProjections` can be used together with [UMAP.jl](https://github.com/dillondaudert/UMAP.jl):
```julia
julia> using UMAP

julia> umapped = umap(reduced, 3)
DataMatrix (3 variables and 34639 observations)
  Matrix{Float64}
  Variables: id
  Observations: id, sampleName, barcode, fraction_mt, nCount_ADT, nFeature_ADT, nCount_RNA, nFeature_RNA, orig.ident, lane, ...
  Models: UMAP(n_components=3), SVD, Filter, Normalization, SCTransform, ...
```
![umap](https://user-images.githubusercontent.com/16546530/213448139-beb04732-3836-4392-b9c1-32f4e04d9a65.svg)

[Download interactive UMAP plot](https://github.com/rasmushenningsson/SingleCellProjections.jl/files/10456847/umap.zip).


#### t-SNE
Similarly, t-SNE plots are supported using [TSne.jl](https://github.com/lejon/TSne.jl).
In this example, we just run it one every 10????? cell, because t-SNE doesn't scale very well with the number of cells:
```julia
julia> using TSne

julia> t = tsne(reduced[:,1:10:end], 3)
DataMatrix (3 variables and 3464 observations)
  Matrix{Float64}
  Variables: id
  Observations: id, sampleName, barcode, fraction_mt, nCount_ADT, nFeature_ADT, nCount_RNA, nFeature_RNA, orig.ident, lane, ...
  Models: NearestNeighborModel(base="tsne", k=10), Filter, SVD, Filter, Normalization, ...
```
![t-SNE](https://user-images.githubusercontent.com/16546530/213448219-397f9c16-cd47-4020-b959-729e59efe73c.svg)

[Download interactive t-SNE plot](https://github.com/rasmushenningsson/SingleCellProjections.jl/files/10456849/t-SNE.zip).


#### Other
It is of course possible to use your own favorite dimension reduction method/package.
The natural input for most cases are the coordinates after dimension reduction by PCA (`obs_coordinates(reduced)`).


### Projections
`SingleCellProjections` is build to make it very easy to project one dataset onto another.

Let's load count data for two more samples:
```julia
julia> sample_paths_proj = joinpath.(base_path, ["GSE164378_RNA_ADT_3P_P5.h5", "GSE164378_RNA_ADT_3P_P6.h5"]);

julia> counts_proj = load_counts(sample_paths_proj; sample_names=["P5","P6"]);

julia> leftjoin!(counts_proj.obs, cell_annotations; on=:barcode);

julia> counts_proj
DataMatrix (33766 variables and 42553 observations)
  SparseArrays.SparseMatrixCSC{Int64, Int32}
  Variables: id, feature_type, name, genome, read, pattern, sequence
  Observations: id, sampleName, barcode, fraction_mt, nCount_ADT, nFeature_ADT, nCount_RNA, nFeature_RNA, orig.ident, lane, ...
```

And project them onto the Force Layout we created above:
```julia
julia> fl_proj = project(counts_proj, fl)
[ Info: Projecting onto VarCountsFractionModel(subset_size=13, total_size=33538, col="fraction_mt")
[ Info: Projecting onto SCTransformModel(nvar=20239, clip=34.32)
[ Info: - Removed 13527 variables that where not found in Model
[ Info: Projecting onto NormalizationModel(rank=2, ~1+num(fraction_mt))
[ Info: Projecting onto FilterModel(:, "celltype.l1"=>#97)
[ Info: Projecting onto SVDModel(nsv=20)
[ Info: Projecting onto NearestNeighborModel(base="force_layout", k=10)
DataMatrix (3 variables and 41095 observations)
  Matrix{Float64}
  Variables: id
  Observations: id, sampleName, barcode, fraction_mt, nCount_ADT, nFeature_ADT, nCount_RNA, nFeature_RNA, orig.ident, lane, ...
  Models: NearestNeighborModel(base="force_layout", k=10), SVD, Filter, Normalization, SCTransform, ...
```
The result looks similar to the force layout plot above, since the donors "P5" and "P6" are similar to donors "P1" and "P2".

![force_layout_projected](https://user-images.githubusercontent.com/16546530/213479253-6616d052-e3d9-4e47-9c82-9ef63f966c07.svg)

[Download interactive Force Layout projection plot](https://github.com/rasmushenningsson/SingleCellProjections.jl/files/10457993/force_layout_projected.zip).

Under the hood, `SingleCellProjections` recorded a `ProjectionModel` for every step of the analysis leading up to the Force Layout.
Let's take a look:
```julia
julia> fl.models
6-element Vector{ProjectionModel}:
 VarCountsFractionModel(subset_size=13, total_size=33538, col="fraction_mt")
 SCTransformModel(nvar=20239, clip=34.32)
 NormalizationModel(rank=2, ~1+num(fraction_mt))
 FilterModel(:, "celltype.l1"=>#97)
 SVDModel(nsv=20)
 NearestNeighborModel(base="force_layout", k=10)
```
When projecting, these models are applied one by one (C.f. output from `project` above), ensuring that the projected data is processed correctly.
In most cases, projecting is **not** the same as running the same analysis independently, since information about the data set is recorded in the model.
