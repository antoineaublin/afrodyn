#!/bin/bash

############      SGE CONFIGURATION      ###################
# Ecrit les erreur dans le fichier de sortie standard 
#$ -j y 

# Shell que l'on veut utiliser 
#$ -S /bin/bash 

# Email pour suivre l'execution 
#$ -M andrew.helmstetter@ird.fr

# Type de massage que l'on recoit par mail
#    -  (b) un message au demarrage
#    -  (e) a la fin
#    -  (a)  en cas d'abandon
#$ -m e 
#$ -V

# Queue que l'on veut utiliser
#$ -q bioinfo.q

# Nom du job
#$ -N paralog_anon
############################################################

# phylogeny with RAxML

###################################################
#### 0 preparation of files and transfer to cluster
###################################################

#### Create paths 

#Input directory must contain the aligned and trimmed fasta files only
#CHECK FORMAT
#no exon names in supercontig fastas
#no duplicate taxa

#recommend changing output directory depending on input dataset
path_to_dir_in="/home/helmstetter/hybpiper_annonidium_1371242/retrieved_par";
path_to_dir_out="/home/helmstetter/raxml_paralog_anon_$JOB_ID/";
path_to_tmp="/scratch/helmstetter_$JOB_ID";

#### Creation du repertoire temporaire sur noeud

echo "Transferring data to node";

mkdir $path_to_tmp
scp -rp nas:/$path_to_dir_in/* $path_to_tmp   ############ Modifier nas/nas2
ls $path_to_tmp

echo "done copying files";

module load bioinfo/RAxML/8.2.9
module load bioinfo/mafft/7.305

cd $path_to_tmp

cat para_table.txt | sort -f | uniq > loci_list.txt

while read i
do
	echo $i
	rm -r ${i}_fastas
	rm ${i}_paralog_fasta_list.txt
	
	find . -name ${i}_paralogs.fasta > ${i}_paralog_fasta_list.txt
	
	mkdir ${i}_fastas
	
	while read j
	do
		nom=$(echo $j | cut -c3-9)
		cp $j ${i}_fastas/${nom}.fasta
	done < ${i}_paralog_fasta_list.txt

	cat ${i}_fastas/* >> ${i}_fastas/combined_${i}.fasta

	echo "starting alignment";

	cd ${i}_fastas
	
	#makes commands for all of the files in the folder and runs them in batches of 12 jobs
	ls -1 ./ | \
		while read sample; do
		  	echo "mafft --auto ${sample} > aligned.${sample}"
		done | parallel -j12
	
	echo "done alignment";

	echo "starting raxml";
	
	raxmlHPC-PTHREADS -f a -x 12345 -p 12345 -T 8 -# 100 -m GTRGAMMA -O -s ./aligned.combined_${i}.fasta -n ${i}
	
	echo "done raxml";

	cd $path_to_tmp

done < loci_list.txt

#Transfer output data

echo "Transfering data from node to master";

mkdir $path_to_dir_out

scp -rp $path_to_tmp/ nas:/$path_to_dir_out/

echo "done transfer";

#### Remove tmp data on node

echo "Deleting data on node";
rm -rf $path_to_tmp
echo "Done deleting, FINISHED!";