cd /home/jacksandy/Documents/pipeline_engine && set -a &&  source .env && \                                                                                                                                           
    for d in output/*/; do                                                                                                                                       
      if [ -f "$d/terraform.tfstate" ]; then                                                                                                                     
        echo "=== Destroying $(basename $d) ==="                                                                                                                 
        terraform -chdir="$d" destroy -input=false -auto-approve                                                                                               
      fi                                                                                                                                                         
    done   
