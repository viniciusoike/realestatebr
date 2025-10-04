import sgs
import pandas as pd
import json

# Import codes
codes = pd.read_csv("data-raw/bacen_codes.csv")
# Convert code column to list
codes_list = codes["code"].tolist()

# Import data on each code and extract metadata
data = sgs.dataframe(codes_list, start='02/01/2018', end='31/12/2018')
metadata_en = sgs.metadata(data)
metadata_pt = sgs.metadata(data, language = "pt")
# Convert to data.frame
df_meta_en = pd.DataFrame(metadata_en)
df_meta_pt = pd.DataFrame(metadata_pt)
# Export csv
df_meta_en.to_csv("data-raw/bacen_metadata_en.csv", index = False)
df_meta_pt.to_csv("data-raw/bacen_metadata_pt.csv", index = False)
