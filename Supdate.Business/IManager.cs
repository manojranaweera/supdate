﻿using System.Collections.Generic;
using Supdate.Model.Base;

namespace Supdate.Business
{
  public interface IManager<T> where T : ModelBase
  {
    T Create(T model);

    T Get(int id);

    IEnumerable<T> GetList(object predicate = null);

    IEnumerable<T> GetList(string whereClause);

    T Update(T model);

    bool Delete(int id);
  }
}
