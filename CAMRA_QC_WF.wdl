# TODO copied from:
#https://github.com/microbiomedata/metaMAGs/blob/master/tasks/checkm.wdl
# I need to change it to suit my own needs. 
version 1.0
workflow assembly_qc {
    input{
        ###inputs to workflow
        File assembly_bin
        #New
        File rawread_bin
        File quast_bin
        #File genus_species
        #File output_file
    }
    # call run_checkM {
    #     input:
    #         assembly_bin = assembly_bin
    # }
    call run_merqury {
        input:
            assembly_bin = assembly_bin,
            rawread_bin = rawread_bin,
            quast_bin = quast_bin
    }
}

task run_checkM {
    input {
        File assembly_bin
        #File species
        #File output_file
    }
    runtime{
        docker: 'danylmb/checkm:latest'

    }
    
    command {
        mkdir /tmp
        export TMPDIR=/tmp
        mkdir output_test
        checkm taxonomy_wf genus "Klebsiella" -t 4 -x fasta ~{assembly_bin} output_test > output_test/checkm_quality_assessment.txt
        cd output_test && rm -rd !(checkm_quality_assessment.txt) && cd ..
    }


    output {
        File checkm_output = "output_test/checkm_quality_assessment.txt"
    }
}

task run_merqury {
    input {
        File assembly_bin
        File rawread_bin
        File quast_bin

    }
    runtime{
        docker: 'miramastoras/merqury:latest'
    }
    
    command <<<
        mkdir merqury_output 
        touch merqury_output/asm_qv.txt
        for read_loc in ~{rawread_bin}/* ; do
            sample_name=$(echo "$read_loc" | cut -d'/' -f9)
            quast_loc="~{quast_bin}/${sample_name}_quast_report.txt" 
            asm_loc="~{assembly_bin}/${sample_name}_contigs.fasta"
            output_loc="merqury_output/${sample_name}"
            if [ -f $quast_loc ] && [ -d $read_loc ] && [ -f $asm_loc ]; then 
                total_length_line=$(grep "Total length   " $quast_loc) 
                total_length=$(echo "$total_length_line" | awk '$0=$NF') 
                best_k=$(best_k.sh $total_length) 
                best_k=$(echo "$best_k" | tail -n 1) 
                mkdir $output_loc 
                meryl k=$best_k count $read_loc/* output $sample_name.meryl  
                mv $sample_name.meryl $output_loc 
                cd $output_loc && merqury.sh $sample_name.meryl $asm_loc $sample_name 
                qv_file="${sample_name}/${sample_name}.qv"
                cd .. # we are in merqury_output
                if [ -f "$qv_file" ]; then
                    cat "$qv_file" >> "asm_qv.txt" 
                fi
                cd .. # we are in executions
            fi
        done
    >>>
    output {
        File checkm_output = "merqury_output/asm_qv.txt"
    }


}