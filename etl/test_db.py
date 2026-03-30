import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from load.loader import get_engine
from sqlalchemy import inspect

engine = get_engine()
with engine.connect() as conn:
    insp = inspect(engine)
    print(insp.get_table_names())
