import csv
import json

def convert_sample():
    input_file = 'mairielist-sample-test.csv'
    output_file = 'mairielist-sample-converted.csv'
    
    with open(input_file, 'r', encoding='utf-8') as infile, \
         open(output_file, 'w', encoding='utf-8', newline='') as outfile:
        
        reader = csv.DictReader(infile)
        fieldnames = ['email', 'name', 'attribs']
        writer = csv.DictWriter(outfile, fieldnames=fieldnames)
        writer.writeheader()
        
        count = 0
        for row in reader:
            email = row.get('email', '').strip()
            nom_commune = row.get('nom_commune', '').strip()
            
            if not email or '@' not in email:
                continue
            
            attribs = {
                'nom_commune': nom_commune,
                'departement_numero': row.get('departement_numero', '').strip(),
                'zipcode': row.get('zipcode', '').strip(),
                'population_commune': row.get('population_commune', '').strip(),
                'code_insee': row.get('code_insee', '').strip(),
                'city': row.get('city', '').strip(),
                'state': row.get('state', '').strip()
            }
            
            clean_attribs = {k: v for k, v in attribs.items() if v and v.lower() not in ['nan', 'null', '']}
            
            writer.writerow({
                'email': email,
                'name': nom_commune or email.split('@')[0],
                'attribs': json.dumps(clean_attribs, ensure_ascii=False)
            })
            
            count += 1
        
        print(f"Échantillon converti : {count} communes")

if __name__ == "__main__":
    convert_sample()
