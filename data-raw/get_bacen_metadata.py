import sgs
import pandas as pd
import json

# Import codes
codes = pd.read_csv("data-raw/bacen_codes.csv")
# Convert code column to list
codes_list = codes["code"].tolist()

print(f"Processing {len(codes_list)} series...")

# Download series in batches to handle potential API issues
batch_size = 10
all_data = {}

for i in range(0, len(codes_list), batch_size):
    batch = codes_list[i:i+batch_size]
    print(f"Processing batch {i//batch_size + 1}: codes {i+1}-{min(i+batch_size, len(codes_list))}")

    try:
        batch_data = sgs.dataframe(batch, start='02/01/2018', end='31/12/2018')
        all_data.update(batch_data.to_dict())
        print(f"  Success: Downloaded {len(batch)} series")
    except Exception as e:
        print(f"  Error in batch: {e}")
        # Try individual series in failed batch
        for code in batch:
            try:
                single_data = sgs.dataframe([code], start='02/01/2018', end='31/12/2018')
                all_data.update(single_data.to_dict())
                print(f"    Individual success: {code}")
            except Exception as e2:
                print(f"    Failed individual series {code}: {e2}")

# Convert combined data back to DataFrame
data = pd.DataFrame(all_data)

if len(data) > 0:
    # Extract metadata
    metadata_en = sgs.metadata(data)
    metadata_pt = sgs.metadata(data, language="pt")

    # Convert to data.frame
    df_meta_en = pd.DataFrame(metadata_en)
    df_meta_pt = pd.DataFrame(metadata_pt)

    # Export csv
    df_meta_en.to_csv("data-raw/bacen_metadata_en.csv", index=False)
    df_meta_pt.to_csv("data-raw/bacen_metadata_pt.csv", index=False)

    print(f"Successfully exported metadata for {len(data.columns)} series")
else:
    print("No data was successfully downloaded")
