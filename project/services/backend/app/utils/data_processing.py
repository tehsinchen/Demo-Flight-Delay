from collections import defaultdict
import pandas as pd

def flight_data(result):
    # Grouping logic: { "Airline Name": ["Flight1", "Flight2"] }
    grouped = defaultdict(list)
    for row in result.mappings():
        grouped[row['airline_name']].append(row['flight_no'])
    
    # Transform to [{ airline_name: str, flight_nos: [] }]
    return [{"airline_name": k, "flight_nos": v} for k, v in grouped.items()]

def delay_histogram(df: pd.DataFrame, column: str = "delay_min"):
    if df.empty:
        return {"labels": [], "values": []}

    # Define bins including infinity for overflow
    # Bins: [-inf, -240, -210, ..., 210, 240, inf]
    bins = [-float('inf')] + list(range(-240, 241, 30)) + [float('inf')]
    
    # Define Labels
    labels = ["< -240"]
    for i in range(1, len(bins) - 2):
        labels.append(f"{bins[i]} to {bins[i+1]}")
    labels.append("> 240")

    # Process data
    df['bin'] = pd.cut(df['delay_min'], bins=bins, labels=labels)
    hist_counts = df['bin'].value_counts().reindex(labels, fill_value=0).to_dict()

    return {
        "labels": list(hist_counts.keys()),
        "values": [int(v) for v in hist_counts.values()]
    }
