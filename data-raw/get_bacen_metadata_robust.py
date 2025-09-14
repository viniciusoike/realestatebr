import sgs
import pandas as pd
import json
import time

# Import codes
codes = pd.read_csv("data-raw/bacen_codes.csv")
codes_list = codes["code"].tolist()

print(f"Processing {len(codes_list)} series...")

# Test a few series first
print("Testing first 3 series...")
for code in codes_list[:3]:
    try:
        test_data = sgs.dataframe([code], start='02/01/2018', end='31/12/2018')
        print(f"  Test success: {code} -> {test_data.shape[0]} observations")
    except Exception as e:
        print(f"  Test failed: {code} -> {e}")

# Process series individually with error handling and delays
successful_series = []
failed_series = []
metadata_list = []

for i, code in enumerate(codes_list):
    if i >= 20:  # Limit to first 20 for testing
        break
        
    print(f"Processing series {code} ({i+1}/{min(20, len(codes_list))})")
    
    try:
        # Add delay to avoid API rate limiting
        if i > 0:
            time.sleep(1)
            
        # Get series data
        series_data = sgs.dataframe([code], start='02/01/2018', end='31/12/2018')
        
        if len(series_data) > 0 and not series_data.empty:
            try:
                # Get metadata
                meta_en = sgs.metadata(series_data)
                meta_pt = sgs.metadata(series_data, language="pt")
                
                # Extract metadata info
                if meta_en and len(meta_en) > 0:
                    meta_record = {
                        'code': code,
                        'title_en': meta_en[0].get('title', ''),
                        'title_pt': meta_pt[0].get('title', '') if meta_pt and len(meta_pt) > 0 else '',
                        'unit_en': meta_en[0].get('unit', ''),
                        'unit_pt': meta_pt[0].get('unit', '') if meta_pt and len(meta_pt) > 0 else '',
                        'source_en': meta_en[0].get('source', ''),
                        'source_pt': meta_pt[0].get('source', '') if meta_pt and len(meta_pt) > 0 else ''
                    }
                    metadata_list.append(meta_record)
                
                successful_series.append(code)
                print(f"  ✓ Success: {code}")
                
            except Exception as meta_e:
                print(f"  ⚠ Data OK but metadata failed for {code}: {meta_e}")
                successful_series.append(code)
        else:
            print(f"  ✗ No data for series {code}")
            failed_series.append(code)
            
    except Exception as e:
        print(f"  ✗ Failed: {code} -> {e}")
        failed_series.append(code)

print(f"\nSummary:")
print(f"  Successful: {len(successful_series)}")
print(f"  Failed: {len(failed_series)}")
print(f"  Metadata extracted: {len(metadata_list)}")

if len(metadata_list) > 0:
    df_metadata = pd.DataFrame(metadata_list)
    df_metadata.to_csv("data-raw/bacen_metadata_test.csv", index=False)
    print(f"Exported {len(metadata_list)} metadata records to bacen_metadata_test.csv")

if len(failed_series) > 0:
    print(f"Failed series: {failed_series}")