task Region_Copynumber {
  File input_cn_hist_root
  File coordinates
  String basename
  Int disk_size
  Int preemptible_tries

  command<<<
    echo -e "SNP\tChromosome\tPhysicalPosition\t${basename}" > "${basename}.cn"
    cat ${coordinates} \
      | cnvnator -root ${input_cn_hist_root} -genotype 100 \
      | awk '{OFS="\t";print $2,$4}' \
      | sed -e s/:/"\t"/g -e s/-/"\t"/g \
      | awk '{OFS="\t"; if($1 !~ /male/){print $1":"$2"-"$3,$1,$2,$4} }' \
      >> "${basename}.cn"

    bgzip "${basename}.cn"
  >>>

  runtime {
    docker: "halllab/cnvnator@sha256:c41e9ce51183fc388ef39484cbb218f7ec2351876e5eda18b709d82b7e8af3a2"
    cpu: "1"
    memory: "1 GB"
    disks: "local-disk " + disk_size + " HDD"
    preemptible: preemptible_tries
  }

  output {
    File output_cn = "${basename}.cn.gz"
  }
}

workflow Gather_Region_Coverage {
  # data inputs
  Array[File] cn_hist_roots
  Array[String] sample_names
  File coordinates

  # system inputs
  Int preemptible_tries

  scatter (i in range(length(cn_hist_roots))) {
    File cn_hist_root = cn_hist_roots[i]
    String sample_name = sample_names[i]

    Float disk_needed = size(cn_hist_root, "GB") + 1

    call Region_Copynumber {
      input:
      input_cn_hist_root = cn_hist_root,
      coordinates = coordinates,
      basename = sample_name,
      disk_size = ceil(disk_needed),
      preemptible_tries = preemptible_tries
    }
  }
  output {
      Array[File] output_cns = Region_Copynumber.output_cn
  }
}
